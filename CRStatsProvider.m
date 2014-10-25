//
//  CRViewController.m
//
//  Created by Callum Ryan on 28/10/2013.
//
//

#import "CRStatsProvider.h"
#import "FMDB.h"

@implementation CRStatsProvider
+ (NSArray *)statsForGuid:(NSString *)guid
{
    //Setup DB
    FMDatabase * smsdb = [FMDatabase databaseWithPath:@"/private/var/mobile/Library/SMS/sms.db"];
    smsdb.logsErrors = NO;
    [smsdb open];
    
    //Check structure
    FMResultSet *columnNamesSet = [smsdb executeQuery:@"PRAGMA table_info(message)"];
    NSMutableArray* columnNames = [[NSMutableArray alloc] init];
    while ([columnNamesSet next]) {
        [columnNames addObject:[columnNamesSet stringForColumn:@"name"]];
    }
    BOOL newStructure = NO;
    if ([[[columnNames valueForKey:@"description"] componentsJoinedByString:@" ; "] rangeOfString:@"guid"].location == NSNotFound) {
        newStructure = NO;
    } else {
        newStructure = YES;
    }

    if (!newStructure) {
        dispatch_async(dispatch_get_main_queue(), ^{
            //Provide me with info of unsupported db structure
            UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
            FMResultSet *rs = [smsdb executeQuery:@"SELECT * FROM message ORDER BY ROWID desc LIMIT 1"];
            BOOL rowFound = NO;
            while ([rs next]) {
                rowFound = 1;
                pasteboard.string =  [NSString stringWithFormat:@"example (delete personal info): \n %@", [[rs resultDict] description]];
            }
            if (!rowFound) {
                pasteboard.string =  [[columnNames valueForKey:@"description"] componentsJoinedByString:@" ; "];
            }
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:@"Sorry your messages structure isn't currently supported, please email c.ryan747@gmail.com with the data copied to your clipboard \n Thanks"  delegate: nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];     
        });
    } else {
        //Get data
        NSString *guidEnd = [[guid componentsSeparatedByString:@";"] objectAtIndex:2];

        int totalCount = [smsdb intForQuery:[NSString stringWithFormat:@"SELECT COUNT(*) FROM chat_message_join WHERE chat_id IN (SELECT ROWID FROM chat WHERE guid LIKE  '%%%@%%')", guidEnd]];
        int sentCount = [smsdb intForQuery:[NSString stringWithFormat:@"SELECT COUNT(*) FROM message where is_from_me = 1 AND ROWID IN (SELECT message_id FROM chat_message_join WHERE chat_id IN (SELECT ROWID FROM chat WHERE guid LIKE  '%%%@%%'))", guidEnd]];
        int receivedCount = totalCount - sentCount;

        [smsdb close];

        NSArray *data = @[[NSNumber numberWithInt:totalCount],[NSNumber numberWithInt:sentCount],[NSNumber numberWithInt:receivedCount]];

        return data;

    }
}
@end