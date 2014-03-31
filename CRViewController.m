//
//  CRViewController.m
//
//  Created by Callum Ryan on 28/10/2013.
//
//

#import "CRViewController.h"
#import "FMDB.h"

@interface CRViewController () {
    NSString *_name;
    NSString *_guid;
    BOOL _gotData;
}

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSMutableArray *data;

- (void)loadStats;
@end

@implementation CRViewController

@synthesize data;

- (id)initWithName:(NSString *)passedName guid:(NSString *)passedGuid
{
    if(self = [super init]){
        _name = passedName;
        _guid = passedGuid;

        UITableView *table = [[UITableView alloc]initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
        table.delegate = self;
        table.dataSource = self;
        [self.view addSubview:table];
        self.tableView = table;
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"Stats";
    
    //Start loading spinner
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [spinner startAnimating];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]initWithCustomView:spinner];
    
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidLoad];

    [self.tableView reloadData];
    [self loadStats];
}

- (void)loadStats
{
    dispatch_queue_t sqlPersonQueue = dispatch_queue_create("SQL Queue", NULL);
    dispatch_async(sqlPersonQueue, ^{
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
            NSString *guidEnd = [[_guid componentsSeparatedByString:@";"] objectAtIndex:2];

            int totalCount = [smsdb intForQuery:[NSString stringWithFormat:@"SELECT COUNT(*) FROM chat_message_join WHERE chat_id IN (SELECT ROWID FROM chat WHERE guid LIKE  '%%%@%%')", guidEnd]];
            int sentCount = [smsdb intForQuery:[NSString stringWithFormat:@"SELECT COUNT(*) FROM message where is_from_me = 1 AND ROWID IN (SELECT message_id FROM chat_message_join WHERE chat_id IN (SELECT ROWID FROM chat WHERE guid LIKE  '%%%@%%'))", guidEnd]];
            int receivedCount = totalCount - sentCount;

            [smsdb close];

            NSMutableArray *tempData = [[NSMutableArray alloc]initWithCapacity:3];

            [tempData addObject:[NSNumber numberWithInt:totalCount]];
            [tempData addObject:[NSNumber numberWithInt:sentCount]];
            [tempData addObject:[NSNumber numberWithInt:receivedCount]];

            self.data = tempData;
            dispatch_async(dispatch_get_main_queue(), ^{
                _gotData = 1;
                self.data = tempData;
                [self.tableView reloadData];
                self.navigationItem.rightBarButtonItem = nil;
            });
        }

    });
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 3;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"cell"];
    }

    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    switch (indexPath.row) {
        case 0:
            cell.textLabel.text = @"Total";
            break;
            
        case 1:
            cell.textLabel.text = @"Sent";
            break;
            
        case 2:
            cell.textLabel.text = @"Received";
            break;
            
    }

    if (_gotData) {
        cell.detailTextLabel.text = [(NSNumber *)[self.data objectAtIndex:indexPath.row]stringValue];
    } else {
        cell.detailTextLabel.text = @"";
    }
    
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return _name;
}

- (BOOL)tableView:(UITableView *)tableView shouldShowMenuForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (BOOL)tableView:(UITableView *)tableView canPerformAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender
{
    if (action == @selector(copy:)) { return YES; } //allow copying
    return NO;
}

- (void)tableView:(UITableView *)tableView performAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender
{
    if (action == @selector(copy:)) {
        //copy cell detail to pasteboard
        UITableViewCell *cell = [self tableView:tableView cellForRowAtIndexPath:indexPath];
        [[UIPasteboard generalPasteboard] setString:cell.detailTextLabel.text];
    }
}

@end
