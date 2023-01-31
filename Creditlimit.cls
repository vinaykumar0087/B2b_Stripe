public with sharing class Creditlimit {
    @AuraEnabled
    public static Map<String, Object> getAccountDetails(String cartId){
        try {
            Map<String, Object> myMap = new Map<String, Object>();
            List<WebCart> cartData = [SELECT Id, AccountId, TotalProductAmount, TotalChargeAmount, GrandTotalAmount, 
            CreatedBy.Contact.Account.Approved_for_Credit__c, CreatedBy.Contact.Account.Credit_Limit__c  
            FROM WebCart WHERE Id=:cartId];

            myMap.put('ApprovedForCredit',cartData[0].CreatedBy.Contact.Account.Approved_for_Credit__c);
            myMap.put('CreditLimit',cartData[0].CreatedBy.Contact.Account.Credit_Limit__c);
            myMap.put('GrandTotalAmount',cartData[0].GrandTotalAmount);

            return myMap;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static string updateCreditLimit(String cartId, Decimal grandTotal, Decimal creditLimit){
        try {
            List<WebCart> cartData = [SELECT Id, AccountId FROM WebCart WHERE Id=:cartId];
            String accountId = cartData[0].AccountId;
            Account a = [SELECT Credit_Limit__c FROM Account WHERE Id =:accountId];
            a.Credit_Limit__c = creditLimit - grandTotal;
            update a;
            return 'Credit Limit Updated';
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}