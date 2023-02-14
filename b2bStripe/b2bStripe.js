/**
 * @description       :
 * @author            : Vinay
 * @group             : RafterOne
 * @last modified on  : 01-13-2023
 * @last modified by  : Vinay
 * Modifications Log
 * Ver   Date         Author     Modification
 * 1.0   01-13-2023   Abhishek   Initial Version
**/
import { LightningElement,api,wire } from 'lwc';
import getPaymentInfo from '@salesforce/apex/B2BPaymentController.getPaymentInfo';
import { NavigationMixin } from 'lightning/navigation';
import setPaymentInfo from '@salesforce/apex/B2BPaymentController.setPaymentInfo';

import getVFOrigin from '@salesforce/apex/B2BPaymentController.getVFOrigin';

import updatePAError from '@salesforce/apex/B2BPaymentController.updatePaymentAuthError';

import submitCreditCardOrder from '@salesforce/apex/B2BPaymentController.submitCreditCardOrder';

import getAccountDetails from '@salesforce/apex/Creditlimit.getAccountDetails';

import updateCreditLimit from '@salesforce/apex/Creditlimit.updateCreditLimit';

import {ShowToastEvent} from 'lightning/platformShowToastEvent';
import { FlowNavigationNextEvent } from 'lightning/flowSupport';

export default class B2bStripe extends LightningElement {

    @api cartId;
    @api poNumber;
    @api selectedBillingAddressId;
    @api paymentType = 'PurchaseOrderNumber';

    cart;
    iframeUrl;
    // Wire getVFOrigin Apex method to a Property
    @wire(getVFOrigin)
    vfOrigin;
    checkLimitButton = true;
    checkLimitData = false;
    canPay = false;
    stripeCustomerId = '';
    iframeUrl;
    showSpinner = false;

    summaryData = {};

    getAccountDetails()
    {
        getAccountDetails({cartId : this.cartId})
        .then(result=>{
            if(result)
            {
                console.log(result);
                this.summaryData = result;
                if(result.ApprovedForCredit==false)
                {
                    this.paymentType = 'CardPayment';
                }
            }
        })
        .catch(error=>{
            console.log('** error' + JSON.stringify(error));
        })
    }

    checkLimitHandler() {
         this.checkLimitButton = false;
         this.checkLimitData = true;
         }
    
    PONumberHandler(event)
    {
        this.poNumber = event.target.value;
    }

    handlePONumber()
    {
        this.paymentType = 'PurchaseOrderNumber';
    }

    handleCreditPayment()
    {
        this.paymentType = 'CardPayment';
    }


    connectedCallback() {
        this.getAccountDetails();
        window.addEventListener("message", this.handleVFResponse.bind(this));
        let dataMap = {
            cartId: this.cartId
        };
        this.showSpinner = true;
        getPaymentInfo({
            dataMap: dataMap
        }).then((result) => {
            console.log(result);
                this.showSpinner = false;
                if (result && result.isSuccess) {
                    this.canPay = result.canPay;
                    this.cart = result.cart;
                    this.stripeCustomerId = result.stripeCustomerId ;
                    this.iframeUrl = result.iframeUrl;
                } else {
                    this.showToast('No payment Methods Found', 'error');
                }
            })
            .catch((e) => {
                this.showToast(
                    'Some Error occured while processing this Opportunity,Please contact System admin.',
                    'error'
                );
            });
    }

    showToast(message ,variant) {
        let title = variant == 'error' ? 'Error' : 'Success';
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(evt);
    }

    handleVFResponse(message){
        console.log('handleVFResponse');
        console.log(message);
        var cmp = this;
        if (message.origin === this.vfOrigin.data) {
            let receivedMessage = message.data;
            if(receivedMessage && receivedMessage != null){
                if(receivedMessage.hasOwnProperty('paId')){
                    let dataMap = {
                        paId: receivedMessage.paId
                    }
                    updatePAError({dataMap: dataMap})
                    .then(function (result) {
                        cmp.showSpinner = false;
                    });
                }else{
                    if(receivedMessage.cToken && receivedMessage.cToken != null &&  receivedMessage.cToken.token && receivedMessage.cToken.token != null){
                        if(this.submitOrderCalled){
                            return ;
                        }
                        this.submitOrderCalled = true;
                        this.submitCCOrder(receivedMessage);
                    }
                }
            }
        }
    }

    submitCCOrder(receivedMessage){
        let dataMap = {
            "cartId": this.cartId,
            "paymentMethod": 'CC',
            "stripeCustomerId": this.stripeCustomerId,
            "cToken": receivedMessage.cToken.token,
            "cPay" : receivedMessage.cPay.paymentIntent,
            "cTokenId": receivedMessage.cToken.token.id,
            "cPayId" : receivedMessage.cPay.paymentIntent.id
        };
        submitCreditCardOrder({
            dataMap: dataMap
        }).then((result) => {
            this.showSpinner = false;
            if(result && result.isSuccess){
                const navigateNextEvent = new FlowNavigationNextEvent();
                this.dispatchEvent(navigateNextEvent);
            }else{
                this.showToast(result.msg,'error');
            }
        }).catch((e) => {
            this.showToast(
                e.message,
                'error'
            );
        });
    }

    errorCallback(err) {
        alert(err);
    }

    submitOrder(){
        console.log(this.paymentType);
        if(this.paymentType=='PurchaseOrderNumber')
        {
            console.log('Inside PO Number');
            if(this.summaryData.GrandTotalAmount < this.summaryData.CreditLimit)
            {
                updateCreditLimit({cartId : this.cartId, grandTotal : this.summaryData.GrandTotalAmount, creditLimit : this.summaryData.CreditLimit})
                .then((result) => {
                    console.log(result);
                }).catch((e) => {
                    console.log('** error' + JSON.stringify(e));
                });
                const navigateNextEvent = new FlowNavigationNextEvent();
                this.dispatchEvent(navigateNextEvent);
            }
            else{
                const event = new ShowToastEvent({
                    title: 'Error',
                    variant: 'error',
                    message: 'Credit Limit $'+this.summaryData.CreditLimit,
                });
                this.dispatchEvent(event);
            }
            
        }
        else{
            console.log('Inside CC')
            let dataMap = {
                "cartId": this.cartId,
                "paymentMethod": 'CC',
                "stripeCustomerId": this.stripeCustomerId
            };
            this.showSpinner = true;
            setPaymentInfo({
                dataMap: dataMap
            }).then((result) => {
                
                if(result && result.PI_Secret){
                    result.billing_details = {
                        name : this.cart.CreatedBy.Name,
                        email : this.cart.CreatedBy.Email
                    };
                    this.handleFiretoVF(result);
                }
            }).catch((e) => {
                this.showToast(
                    e.message,
                    'error'
                );
            });
        }
    }

    handleFiretoVF(message) {
        console.log('handleFiretoVF');
        this.template.querySelector("iframe").contentWindow.postMessage(message, this.vfOrigin.data);
    }

}