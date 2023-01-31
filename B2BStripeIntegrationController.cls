/**
 * @description       : 
 * @author            : Abhishek
 * @group             : RafterOne
 * @last modified on  : 01-13-2023
 * @last modified by  : Abhishek
 * Modifications Log
 * Ver   Date         Author     Modification
 * 1.0   01-13-2023   Abhishek   Initial Version
**/
public with sharing class B2BStripeIntegrationController {


    public static B2B_Payment_Gateway_Setting__mdt getStripeConfiguration(){

        B2B_Payment_Gateway_Setting__mdt paymentConfigration;
        String AccountId = [SELECT AccountId,Account.currencyIsoCode FROM User WHERE Id=:userInfo.getUserId()].AccountId;
        User u = [SELECT AccountId,Account.currencyIsoCode FROM USER where Id=:userInfo.getUserId() limit 1 ];
        if(U != null){
            List<B2B_Payment_Gateway_Setting__mdt> paymentConfigrationList = [SELECT Id, DeveloperName, MasterLabel, Label, QualifiedApiName, Api_Key__c, Country__c, EndPoint_URL__c, Entity_Name__c, Public_Key__c, Stripe_Account_Name__c, User_Locale__c, WebStore__c, Currency__c FROM B2B_Payment_Gateway_Setting__mdt WHERE Currency__c=:u.Account.currencyIsoCode LIMIT 1];
            if(!paymentConfigrationList.isEmpty()){
                paymentConfigration = paymentConfigrationList.get(0);
            }
        }
        return paymentConfigration;
    }

    public static Map<String,Object> getPaymentOptions(Map<String,Object> dataMap){
        Boolean isSuccess = false;
        String message = '';
        if(dataMap.containsKey(B2BConstants.CART_ID) && String.isNotBlank((String)dataMap.get(B2BConstants.CART_ID)) )  {
            String cartId = (String)dataMap.get(B2BConstants.CART_ID) ;
            WebCart cart = [SELECT Id,CreatedBy.Name,CreatedBy.Email,currencyISOCode,GrandTotalAmount,AccountId,BillingStreet,BillingCity,BillingState,BillingCountry,BillingPostalCode FROM WEBCART WHERE Id=:cartId LIMIT 1];
            dataMap.put('cart',cart);
            Boolean canPay = false;
            B2B_Payment_Gateway_Setting__mdt stripeConfig = getStripeConfiguration() ;
            if(stripeConfig!=null){
                canPay = true;
                dataMap.put('stripConfig',stripeConfig);
                dataMap.put('iframeUrl','https://training202104--mkrishna.sandbox.my.site.com/HeroCycles/apex/B2BStripePay?pKey='+stripeConfig.public_Key__c);
                String stripeCustomerId = getStripeCustomerId(stripeConfig);
                dataMap.put('stripeCustomerId',stripeCustomerId);
            }
            dataMap.put('canPay',canPay);
            isSuccess = true;
        }
        dataMap.put(B2BConstants.IS_SUCCESS,isSuccess);
        dataMap.put(B2BConstants.MESSAGE,message);
        return dataMap;
    }

    public static string getStripeCustomerId(B2B_Payment_Gateway_Setting__mdt stripeConfig){
        String stripeCustomerId;
        List<User> userList = [SELECT AccountId, Account.Name,Account.B2B_Stripe_Customer_ID__c FROM User WHERE Id=:userInfo.getUserId() AND AccountId != null LIMIT 1];
        if(!userList.isEmpty() ){
            User user = userList.get(0) ;
            stripeCustomerId = user.Account.B2B_Stripe_Customer_ID__c;
            if(String.isBlank(stripeCustomerId)){
                HttpRequest http = new HttpRequest();
                String customerUrl = stripeConfig.EndPoint_URL__c+'customers';
                String apiKey =  stripeConfig.Api_Key__c;
                String stripeAccountName = user.Account.Name;
                Blob headerValue = Blob.valueOf(apiKey + ':');
                String authorizationHeader = 'BASIC ' +EncodingUtil.base64Encode(headerValue);
                String body = 'name='+stripeAccountName;
                HttpResponse resp = new HttpResponse();
                resp = stripeRestAPICall(customerUrl,authorizationHeader,body,'POST');
                string response = resp.getBody();
                B2BStripeModel stripeCustomerResponse = parseTokenResponse(response);
                Account customerAccount = new Account(Id = user.AccountId);
                customerAccount.B2B_Stripe_Customer_ID__c = stripeCustomerResponse.CustomerId;
                update customerAccount;
                stripeCustomerId = stripeCustomerResponse.CustomerId;
            }
        }
        return stripeCustomerId;
    }

    public static HttpResponse stripeRestAPICall(String stripeEndpoint, String authorizationHeader,String requestBody,String method )
    {
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        HttpResponse resp = new HttpResponse();
        req.setEndpoint(stripeEndpoint);
        req.setHeader('Authorization', authorizationHeader);
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setMethod(method);
        req.setBody(requestBody);
        req.setTimeout(40000);
        if(Test.isRunningTest()){
            HTTPResponse res = new HTTPResponse();
            res.setBody('{"success":"true"}');
            res.setStatus('Success');
            res.setStatusCode(200);
            return res;
        }else{
            return http.send(req);
        }
    }

    public static B2BStripeModel parseTokenResponse(String responseBody){
        system.debug('responseBody-->'+responseBody);
        B2BStripeModel sModel   = new B2BStripeModel();
        JSONParser parser = JSON.createParser(responseBody);
        system.debug('parser-->'+parser);
        boolean isSrcValue = false;
        while(parser.nextToken() != null){
            if (parser.getCurrentToken() == JSONToken.FIELD_NAME) {
                if(parser.getText() == 'id'){
                    parser.nexttoken();
                    sModel.id= parser.getText();
                }
                if(parser.getText() == 'object' && !(isSrcValue)){
                    isSrcValue = true;
                    parser.nexttoken();
                    sModel.transactionObject= parser.getText();
                    if (sModel.transactionObject == 'charge'){
                        sModel.stripeTransactionToken = sModel.id;
                    } else if (sModel.transactionObject == 'customer') {
                        sModel.CustomerId = sModel.id;
                    }
                }
                if(parser.getText() == 'amount'){
                    parser.nexttoken();
                    sModel.chargeAmount = decimal.valueOf(parser.getText());
                }
                if(parser.getText() =='currency'){
                    parser.nexttoken();
                    sModel.currencyCode=parser.getText();
                }
                if(parser.getText() =='type'){
                    parser.nexttoken();
                    sModel.type= parser.getText();
                }
                if(parser.getText() == 'source'){
                    isSrcValue = true;
                    while(parser.nextToken() != null){
                        if (parser.getCurrentToken() == JSONToken.FIELD_NAME) {
                            if (parser.getText() == 'last4'){
                                parser.nexttoken();
                                sModel.cardLastFourDigit= parser.getText();
                            }
                            if (parser.getText() == 'exp_month'){
                                parser.nexttoken();
                                sModel.cardExpiryMonth = parser.getText();
                            }
                            if (parser.getText() == 'exp_year'){
                                parser.nexttoken();
                                sModel.cardExpiryYear = parser.getText();
                            }
                            if (parser.getText() == 'country'){
                                parser.nexttoken();
                                sModel.country = parser.getText();
                            }
                            if (parser.getText() == 'brand'){
                                parser.nexttoken();
                                sModel.brand= parser.getText();
                            }
                        }
                    }
                }
                else
                    if(parser.getText() == 'data'){
                        while(parser.nextToken() != null){
                            if (parser.getCurrentToken() == JSONToken.FIELD_NAME){
                                if (parser.getText() == 'last4'){
                                    parser.nexttoken();
                                    sModel.cardLastFourDigit= parser.getText();
                                }
                                if (parser.getText() == 'exp_month'){
                                    parser.nexttoken();
                                    sModel.cardExpiryMonth= parser.getText();
                                }
                                if (parser.getText() == 'exp_year'){
                                    parser.nexttoken();
                                    sModel.cardExpiryYear= parser.getText();
                                }
                                if (parser.getText() == 'country'){
                                    parser.nexttoken();
                                    sModel.country= parser.getText();
                                }
                                if (parser.getText() == 'brand'){
                                    parser.nexttoken();
                                    sModel.brand= parser.getText();
                                }
                            }
                        }
                    }
                else
                    if(parser.getText() == 'Error'){
                        while(parser.nextToken() != null){
                            if (parser.getCurrentToken() == JSONToken.FIELD_NAME){
                                if (parser.getText() == 'message'){
                                    parser.nexttoken();
                                    sModel.stripeChargeProcessError= parser.getText();
                                }
                            }
                        }
                    }
            }
        }
        return sModel;
    }

    public static Map<String, String> setPaymentInfo(Map<String,Object> dataMap) {
        String stripeCustomerId = (String)dataMap.get('stripeCustomerId');
        String cartId = (String)dataMap.get(B2BConstants.CART_ID) ;
        String orderId = '' ;
        List<CartCheckoutSession> sessions = getActiveCheckoutSessions(cartId);
        if(!sessions.isEmpty()){
            orderId = sessions.get(0).OrderId;
        }
        Map<String, String> PaymentResultInfo = new Map<String, String>();
        Map<String, Object> selectedBillingAddress = new Map<String, Object>();
        Map<String, Object> paymentInfo = new Map<String, Object>();
        ConnectApi.AuthorizationRequest authRequest = new ConnectApi.AuthorizationRequest();
        WebCart cart = [SELECT Id,CreatedBy.Name,WebStoreId,CreatedBy.Email,currencyISOCode,GrandTotalAmount,AccountId,BillingStreet,BillingCity,BillingState,BillingCountry,BillingPostalCode FROM WEBCART WHERE Id=:cartId LIMIT 1];
        try {
            authRequest.amount = cart.GrandTotalAmount;
            authRequest.accountId = cart.AccountId;
            authRequest.effectiveDate = Datetime.now();
            authRequest.currencyIsoCode = cart.currencyIsoCode;
            String paymentGatewayId = getPaymentGatewayId(cart.WebStoreId);
            if (paymentGatewayId == null || paymentGatewayId.equals('')) {
                throw new AuraHandledException('This store is not authorized to process payments.');
            }
            authRequest.paymentGatewayId = paymentGatewayId;
            authRequest.paymentMethod = getPaymentMethod(cart);
            authRequest.paymentGroup = getPaymentGroup(cart,orderId);
            authRequest.additionalData = new Map<String, String>{'stripeCustomerId' => stripeCustomerId ,'cartId' => cartId ,'orderId'=>orderId};
            if(!Test.isRunningTest())
            {
                ConnectApi.AuthorizationResponse authResponse = ConnectApi.Payments.authorize(authRequest);
                ConnectApi.AuthorizationGatewayResponse authGatewayRes = authResponse.gatewayResponse;
                System.debug('____authResponse____'+authResponse);
                System.debug('____authResponse____result'+ JSON.serialize(authResponse));
                if (authResponse.error != null) {
                    System.debug('____authResponse____error'+ JSON.serialize(authResponse.error));
                    throw new AuraHandledException('AuthResponseError: ' + authResponse.error.message);
                }
                if(authGatewayRes !=null){
                    PaymentResultInfo.put('PI_Secret',authGatewayRes.gatewayResultCodeDescription);
                }
                if(authResponse.paymentAuthorization !=null){
                    ConnectApi.PaymentAuthorizationResponse paymentAuthResp = authResponse.paymentAuthorization;
                    PaymentResultInfo.put('PA_Id',paymentAuthResp.id);
                }
                system.debug('PaymentResultInfo:: ' + JSON.serialize(PaymentResultInfo));
                dataMap.put(B2BConstants.IS_SUCCESS,true);
                dataMap.put(B2BConstants.CART_ID,cartId);
                dataMap.put(B2BConstants.ORDER_ID,orderId);
            }
            return PaymentResultInfo;
        } catch(ConnectApi.ConnectApiException e) {
            throw new AuraHandledException(e.getMessage());
        } catch (Exception e) {
            throw new AuraHandledException('Message: ' + e.getMessage() + ' --- ' + 'Type: ' + e.getTypeName() + '----' + ' _STACK_: ' + e.getStackTraceString());
        }
    }

    public static List<CartCheckoutSession> getActiveCheckoutSessions(Id cartId) {
        return (cartId != null) ? [
                SELECT
                        Id,
                        OrderId
                FROM CartCheckoutSession
                WHERE WebCartId = :cartId AND IsArchived = FALSE
        ] : new List<CartCheckoutSession>();
    }

    private static String getPaymentGatewayId(String webStoreId) {
        return [SELECT Integration FROM StoreIntegratedService WHERE ServiceProviderType='Payment' AND StoreId=:webStoreId].Integration;
    
    }
    @testVisible
    private static ConnectApi.PaymentGroupRequest getPaymentGroup(WebCart cart,String orderId) {
        ConnectApi.PaymentGroupRequest paymentGroup = new ConnectApi.PaymentGroupRequest();
        paymentGroup.createPaymentGroup = true;
        paymentGroup.currencyIsoCode = cart.currencyIsoCode;
        paymentGroup.sourceObjectId = orderId;            
        return paymentGroup;
    }
    @testVisible
    private static ConnectApi.AuthApiPaymentMethodRequest getPaymentMethod(WebCart cart) {
    
        
        ConnectApi.AuthApiPaymentMethodRequest authApiMethod = new ConnectApi.AuthApiPaymentMethodRequest();
        
        ConnectApi.CardPaymentMethodRequest paymentMethod = new ConnectApi.CardPaymentMethodRequest();
        
        
        paymentMethod.cardCategory = ConnectApi.CardCategory.CreditCard;
        paymentMethod.cardHolderName = 'cardHolderName';
        paymentMethod.cardNumber = '4111111111111111';//Dummy Card Number value to bypass required field
        paymentMethod.cardType = 'Visa';//Dummy Card Type value to bypass required field
        paymentMethod.cvv = '123';//Dummy Card CVV value to bypass required field
        paymentMethod.expiryMonth = 12;//Dummy Card Expiry Month value to bypass required field
        paymentMethod.expiryYear = 2023;    //Dummy Card Expiry Year value to bypass required field    
        authApiMethod.cardPaymentMethod = paymentMethod;
        
        // Pass address from the Payment Form
        ConnectApi.AddressRequest address = new ConnectApi.AddressRequest();
        address.street = cart.BillingStreet;
        address.city = cart.BillingCity;
        address.state = cart.BillingState;
        address.country = cart.BillingCountry;
        address.postalCode = cart.BillingPostalCode;
        
        authApiMethod.address = address;
        authApiMethod.saveForFuture = false;
        //authApiMethod.id = ''; // PaymentMethod record ID.
        return authApiMethod;
    }

    public static Map<String,Object> chargeCustomer(Map<String,Object> dataMap){
        Boolean isSuccess = false;
        String message = '';
        String cartId = (String)dataMap.get(B2BConstants.CART_ID) ;
        WebCart cart = [SELECT Id,CreatedBy.Name,CreatedBy.Email,currencyISOCode,GrandTotalAmount,AccountId,BillingStreet,BillingCity,BillingState,BillingCountry,BillingPostalCode FROM WEBCART WHERE Id=:cartId LIMIT 1];
        String currencyCode = cart.currencyISOCode;
        Decimal amount  = cart.GrandTotalAmount ;
        Integer intAmount = Integer.valueOf(amount*100);
        B2B_Payment_Gateway_Setting__mdt stripeConfig = getStripeConfiguration() ;

        // Map<String, String> params = new Map<String, String>();
        // params.put('amount', String.valueOf(intAmount));
        // params.put('currency', currencyCode);
        // params.put('customer', (String)dataMap.get('stripeCustomerId') );
        // params.put('source', (String)dataMap.get('cTokenId'));
        // String customerUrl = stripeConfig.EndPoint_URL__c+'charges';
        // String apiKey =  stripeConfig.Api_Key__c;
        // Blob headerValue = Blob.valueOf(apiKey + ':');
        // String authorizationHeader = 'BASIC ' +EncodingUtil.base64Encode(headerValue);
        // HttpResponse response = stripeRestAPICall(customerUrl,authorizationHeader,B2BStripeAdapter.urlEncodedParams(params),'POST');

        if( true){
            Map<String, String> params = new Map<String, String>();
            //params.put('amount', String.valueOf(intAmount));
            String customerUrl = stripeConfig.EndPoint_URL__c+'payment_intents/'+(String)dataMap.get('cPayId')+'/capture';
            String apiKey =  stripeConfig.Api_Key__c;
            Blob headerValue = Blob.valueOf(apiKey + ':');
            String authorizationHeader = 'BASIC ' +EncodingUtil.base64Encode(headerValue);
            HttpResponse response = stripeRestAPICall(customerUrl,authorizationHeader,B2BStripeAdapter.urlEncodedParams(params),'POST');
            Map<String,Object> responseMap = (Map<String,Object>)JSON.deserializeUntyped(response.getBody());
            if(responseMap.containsKey('latest_charge')){
                // Map<String,Object> chargeMap = (Map<String,Object>)responseMap.get('charges');
                // if(chargeMap.containsKey('data')){
                //     Map<String,Object> chargeDataMap = (Map<String,Object>)( (List<Object>)chargeMap.get('data')).get(0);
                //     //cart.paymentMethodId = null;
                //     // Commenting the closing of the cart here, creating issues on the next step
                //     // Cart will be closed in the flow in the downstream process
                //     //cart.status = B2BConstants.CART_CLOSED;
                //     //update cart;
                //     dataMap.put('chargeId', (String)chargeDataMap.get('id'));
                //     dataMap.put(B2BConstants.IS_SUCCESS,true);
                // }
                dataMap.put('chargeId', (String)responseMap.get('latest_charge'));
                dataMap.put(B2BConstants.IS_SUCCESS,true);
            }else{
                if(responseMap.containsKey('error')){
                    Map<String,Object> errMap = (Map<String,Object>)responseMap.get('error');
                    if(errMap.containsKey('payment_intent')){
                        Map<String,Object> piResponseMap = (Map<String,Object>)errMap.get('payment_intent');
                        if(piResponseMap.containsKey('charges')){
                            Map<String,Object> chargeMap = (Map<String,Object>)piResponseMap.get('charges');
                            if(chargeMap.containsKey('data')){
                                Map<String,Object> chargeDataMap = (Map<String,Object>)( (List<Object>)chargeMap.get('data')).get(0);
                                dataMap.put('chargeId', (String)chargeDataMap.get('id'));
                                dataMap.put(B2BConstants.IS_SUCCESS,true);
                            }
                        }
                    }else{
                        dataMap.put(B2BConstants.IS_SUCCESS,false);
                    }
                }else{
                }
            }
        }else{
            // Commenting the closing of the cart here, creating issues on the next step
            // Cart will be closed in the flow in the downstream process
            //cart.status = B2BConstants.CART_CLOSED;
            //update cart;
            dataMap.put('chargeId', (String)dataMap.get('cPayId'));
            dataMap.put(B2BConstants.IS_SUCCESS,true);
        }
        
        
        return dataMap;

    }
}