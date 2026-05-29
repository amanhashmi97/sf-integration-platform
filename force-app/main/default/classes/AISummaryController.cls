public with sharing class AISummaryController {

    @AuraEnabled
    public static String generateSummary(Id recordId) {
        try {
            ConnectApi.EinsteinPromptTemplateGenerationsInput input =
                new ConnectApi.EinsteinPromptTemplateGenerationsInput();

            // ✅ Required
            input.isPreview = false;

            // ✅ Required
            input.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
            input.additionalConfig.applicationName = 'PromptBuilderPreview';

            // ✅ Required — record input
            ConnectApi.WrappedValue recordValue = new ConnectApi.WrappedValue();
            recordValue.value = new Map<String, Object>{ 'id' => (String) recordId };

            input.inputParams = new Map<String, ConnectApi.WrappedValue>{
                'Input:Application__c' => recordValue
            };

            // ✅ Call
            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation result =
                ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
                    'Application_AI_Summary',
                    input
                );

            String summaryText = result.generations[0].text;

            // ✅ Only remove markdown symbols, keep punctuation
            summaryText = summaryText.replace('**', '');
            summaryText = summaryText.replace('__', '');
            summaryText = summaryText.replaceAll('#+\\s', '');
            summaryText = summaryText.trim();

            return summaryText;

        } catch (ConnectApi.ConnectApiException e) {
            throw new AuraHandledException('ConnectApi error: ' + e.getMessage());
        } catch (Exception e) {
            throw new AuraHandledException('AI Summary failed: ' + e.getMessage());
        }
    }
}