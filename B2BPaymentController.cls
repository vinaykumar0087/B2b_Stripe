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
public with sharing class B2BPaymentController {

    @AuraEnabled
    public static map<String,Object> getPaymentInfo(map<String,Object> dataMap){
        String methodName = 'getPaymentInfo';
        String supportData = '';
        try{
            dataMap = B2BStripeIntegrationController.getPaymentOptions(dataMap);
        } catch (Exception ex) {
            dataMap = dataMap==null ? new Map<String,Object>() : dataMap ;
            dataMap.put(B2BConstants.IS_SUCCESS,false);
            dataMap.put(B2BConstants.MESSAGE,ex.getMessage()+' '+ex.getStackTraceString());
        }
        return dataMap;
    }

    @AuraEnabled(cacheable=true)
    public static string getVFOrigin() {
        return 'https://training202104--mkrishna.sandbox.my.site.com';
    }

    @AuraEnabled
    public static map<String,Object> setPaymentInfo(map<String,Object> dataMap){
        String methodName = 'setPaymentInfo';
        String supportData = '';
        try{
            dataMap = B2BStripeIntegrationController.setPaymentInfo(dataMap);
        } catch (Exception ex) {
            dataMap = dataMap==null ? new Map<String,Object>() : dataMap ;
            dataMap.put(B2BConstants.IS_SUCCESS,false);
            dataMap.put(B2BConstants.MESSAGE,ex.getMessage());
        }
        return dataMap;
    }

    @AuraEnabled
    public static map<String,Object> updatePaymentAuthError(map<String,Object> dataMap){
        String methodName = 'updatePaymentAuthError';
        String supportData = '';
        try{
            String paId = (String)dataMap.get('paId') ;
            List<PaymentAuthorization> paList = [SELECT Id, Status, GatewayAuthCode, SfResultCode FROM PaymentAuthorization WHERE Id =: paId LIMIT 100];
            for(PaymentAuthorization pa: paList){ pa.status = 'Canceled';
            }
            if(!paList.isEmpty()){ update paList;
            }
        } catch (Exception ex) {
            dataMap = dataMap==null ? new Map<String,Object>() : dataMap ;
            dataMap.put(B2BConstants.IS_SUCCESS,false);
            dataMap.put(B2BConstants.MESSAGE,ex.getMessage());
        }finally
        {
            //B2BUtils.handleApplicationLogging(dataMap);
        }
        return dataMap;
    }

    @AuraEnabled
    public static map<String,Object> submitCreditCardOrder(map<String,Object> dataMap){
        String methodName = 'submitCreditCardOrder';
        String supportData = '';
        try{
            dataMap = B2BStripeIntegrationController.chargeCustomer(dataMap);
            updateOrderInformation(dataMap);
        } catch (Exception ex) {
            dataMap = dataMap==null ? new Map<String,Object>() : dataMap ;
            dataMap.put(B2BConstants.IS_SUCCESS,false);
            dataMap.put(B2BConstants.MESSAGE,ex.getMessage());
        }finally
        {
            //B2BUtils.handleApplicationLogging(dataMap);
        }
        return dataMap;
    }

    public static map<String,Object> updateOrderInformation(map<String,Object> dataMap){
        String cartId = (String)dataMap.get(B2BConstants.CART_ID) ;
        String paymentMethod = (String)dataMap.get('paymentMethod') ;
        List<CartCheckoutSession> sessions = B2BStripeIntegrationController.getActiveCheckoutSessions(cartId);
            if(!sessions.isEmpty() && String.isNotBlank(sessions.get(0).OrderId)){
                String orderId = sessions.get(0).OrderId;
                Order o = new Order();
                o.Id = orderId;
                o.Stripe_Transaction_ID__c =  (String)dataMap.get('chargeId')   ;
                update o;
            }
        return dataMap;
    }

}