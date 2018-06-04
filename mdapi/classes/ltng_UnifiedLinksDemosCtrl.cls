/**
 * Controller for the ltng_UnifiedLinksDemos page
 **/
public with sharing class ltng_UnifiedLinksDemosCtrl {
    
    /** List of demo objects **/
    public UnifiedLinkDemo[] demoWrappers {get;set;}

    //-- Target page reference for the playground
    public PageReference PLAYGROUND = Page.ltng_UnifiedLinksPortal;

    //-- unified demos that need to be generated on the fly
    /** unified demo for SObjects **/
    public static final String UNIFIED_LINK_SOBJECT = 'SObject';

    /**
     * A map that provides an example set of code
     * 
     * <p>This code only really is used for demoing
     * so it shouldn't be included within the object
     * and the user can of course change it within the demo</p>
     * 
     * <p>It should not be a custom metadata because
     * it would need to be re-generated on setup.
     * While it is possible to create Custom Metadata
     * through Apex:
     * https://ashwanisoni.wordpress.com/2017/05/02/create-or-update-custom-metadata-type-via-apex-code-salesforce-summer-17/
     * the destruction / recreation required with upgrades
     * would make it challenging with little benefit and some risk</p>
     * 
     * <p>It should not be a custom setting (via list)
     * as focus is moving away from List based Custom Settings
     * (even though they would easily solve the same problems
     * and address issues found with Custom Metadata).</p>
    **/
    //public static final Map<String,UnifiedLinkDemo> unifiedLinkDemos 

    /** Static initializer for the UnifiedLinkDemos **/
    /*
    public static UnifiedLinkDemo[] initializeUnifiedLinkDemos(){
        return null;
    }
    */
    /*
    public static UnifiedLinkDemo[] initializeUnifiedLinkDemos(){
        UnifiedLinkDemo demo;
        Map<String,UnifiedLinkDemo> results = new Map<String,UnifiedLinkDemo>(
            'VisualForce' => new UnifiedLinkDemo(
                UnifiedLinkExternalId = 'VisualForce',
                ExampleParamsForDemo = '{ "PageName": "ltng_ExampleVF_Page", "Parameters": "?message=Hi Everybody!" }'
            ),
            'ObjectManagerHome' => new UnifiedLinkDemo(
                UnifiedLinkExternalId = 'ObjectManagerHome',
                ExampleParamsForDemo = '{}'
            )
        );
        */

        //-- @TODO: add in at least one unified link demo for sObject reference
        /*
        try {
            ltng_UnifiedLinkScheme__c sObjectLinkScheme = [
                SELECT Id, ExternalId__c
                FROM ltng_UnifiedLinkScheme__c
                WHERE ExternalId__c = :UNIFIED_LINK_SOBJECT
            ];
            results.add( UNIFIED_LINK_SOBJECT, new UnifiedLinkDemo(
                UnifiedLinkExternalId = UNIFIED_LINK_SOBJECT,
                ExampleParamsForDemo = '{ "id": "' + sObjectLinkScheme.id + '" }'
            ));
        }
        */
        /*
        return results;
    }
    */

    public ltng_UnifiedLinksDemosCtrl(){
        ltng_UnifiedLinkScheme__c[] schemesForDemo = getSchemesForDemo();
        this.demoWrappers = getDemoWrappers( schemesForDemo );

        //-- @TODO: re-evaluate whether we need to include an SObject
        //-- dynamic component here.
        //-- Seems no, because we handle that during setup.
    }

    /**
     * Determines all the unified link schemes we want to demo
     * @return ltng_UnifiedLinkScheme__c[]
     **/
    public static ltng_UnifiedLinkScheme__c[] getSchemesForDemo(){
        //-- for now, lets include all
        //-- but we would require a for loop to check
        //-- if we want to only include records
        //-- where ExampleParamsForDemo__c != null
        //-- (as it is a longtext)

        return([
            SELECT Id, Name, Description__c, ExternalId__c,
                RedirectionPrompt__c,
                UrlSchemeClassic__c, UrlSchemeLightningExperience__c,
                ExampleParamsForDemo__c
            FROM ltng_UnifiedLinkScheme__c
        ]);
    }

    /**
     * Generates all the UnifiedLinkDemo records
     * @param ltng_UnifiedLinkScheme__c[] targetSchemes
     * @return UnifiedLinkDemo[] - wrapped schemes.
     **/
    public static UnifiedLinkDemo[] getDemoWrappers( ltng_UnifiedLinkScheme__c[] targetSchemes){
        UnifiedLinkDemo[] results = new UnifiedLinkDemo[]{};
        UnifiedLinkDemo demo;

        if( targetSchemes != null ){
            for( ltng_UnifiedLinkScheme__c targetScheme : targetSchemes ){
                demo = new UnifiedLinkDemo( targetScheme );
                results.add( new UnifiedLinkDemo( targetScheme ));
            }
        }

        return results;
    }

    public class UnifiedLinkDemo {

        /** the Unified Link Scheme we want to demo **/
        public ltng_UnifiedLinkScheme__c targetScheme {get;set;}

        /** demo setup page **/
        public String demoAddress {get;set;}

        /** demo execute address **/
        public String executeAddress {get;set;}

        /** demo execute address **/
        public String recordAddress {get;set;}

        public UnifiedLinkDemo( ltng_UnifiedLinkScheme__c targetScheme ){
            this.targetScheme = targetScheme;

            this.demoAddress = ltng_UnifiedLinksPortalCtrl.createRedirect(
                Page.ltng_UnifiedLinksPortal,
                targetScheme.Externalid__c,
                targetScheme.ExampleParamsForDemo__c,
                true
            ).getUrl();

            this.executeAddress = ltng_UnifiedLinksPortalCtrl.createRedirect(
                Page.ltng_UnifiedLinksPortal,
                targetScheme.Externalid__c,
                targetScheme.ExampleParamsForDemo__c,
                false
            ).getUrl();

            this.recordAddress = new PageReference(
                '/' + targetScheme.Id
            ).getUrl();
        }
    }
}