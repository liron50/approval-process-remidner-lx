public with sharing class SearchRecordsController {
    //Search records
    @AuraEnabled
    public static List<sObject> search(String objectName, List<String> fields, String searchTerm){
        String searchKeyword = searchTerm + '*';
        String returningQuery = '';
        returningQuery = objectName+' ( Id, '+String.join(fields,',')+')';
        String query = 'FIND :searchKeyword IN ALL FIELDS RETURNING '+returningQuery+' LIMIT 20';
        System.debug(' query '+query);
        List<List<sObject>> searchRecords = Search.Query(Query);
        return searchRecords.get(0);
    }

    //Get current record when the component load
    @AuraEnabled
    public static sObject getRecordInit(String objectName, List<String> fields, String recordId){

        String queryFields = 'Id,Name,';

        for(String field : fields){
            if(! queryFields.contains(field + ',')){
                queryFields += field + ',';
            }
        }

        String query = 'SELECT ' + String.escapeSingleQuotes(queryFields.removeEnd(',')) + ' FROM ' + String.escapeSingleQuotes(objectName) + ' WHERE Id = \'' + String.escapeSingleQuotes(recordId) + '\'';
        System.debug(' query '+query);
        
        return Database.query(query);
    }
}
