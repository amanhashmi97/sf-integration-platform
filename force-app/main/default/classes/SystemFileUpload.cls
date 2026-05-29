public without sharing class SystemFileUpload {

    public static void linkFile(Id appId, String fileName, String fileContent) {
        if (String.isBlank(fileContent) || String.isBlank(fileName)) return;

        insert new ApplicationDocument__c(
            Application__c  = appId,
            File_Name__c    = fileName,
            File_Content__c = fileContent,
            Uploaded_By__c  = 'Guest User'
        );

        insert new ContentVersion(
            Title                  = fileName,
            PathOnClient           = fileName,
            VersionData            = EncodingUtil.base64Decode(fileContent),
            IsMajorVersion         = true,
            FirstPublishLocationId = appId
        );
    }
}