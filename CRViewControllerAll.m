//
//  CRViewControllerAll.m
//
//  Created by Callum Ryan on 30/10/2013.
//

#import "CRViewControllerAll.h"
#import "FMDB.h"


@interface CRViewControllerAll () {
    NSString *_name;
    NSString *_guid;
    UISegmentedControl *_control;
    BOOL _loadingStats;
    BOOL _isIphone;
    BOOL _newStructure;
    int _tableNumber; // 0 = nil , 1 = all, 2 = month
}

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSArray *allData;
@property (nonatomic, strong) NSMutableArray *monthData;

- (void)loadAllStats;
- (void)segmentChanged:(UISegmentedControl *)control;
@end

@implementation CRViewControllerAll

@synthesize allData, monthData;

- (id)init
{
    if(self = [super init]){
        UITableView *table = [[UITableView alloc]initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
        table.delegate = self;
        table.dataSource = self;
        [self.view addSubview:table];
        self.tableView = table;
    }

    if([[UIDevice currentDevice].model isEqualToString:@"iPhone"]) {
        _isIphone = YES;
    }

    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"Stats";
    
    //Add loading spinner
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [spinner startAnimating];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]initWithCustomView:spinner];
}

- (void)viewWillAppear:(BOOL)animated
{
    //Add UISegmentedControl
    UIView *containerView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, self.tableView.frame.size.width, 44)];
    UISegmentedControl *segmentedControl = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:@"All", @"Last 28 days", nil]];
    segmentedControl.frame = CGRectMake(15, 15, self.tableView.frame.size.width -30, 29);
    segmentedControl.selectedSegmentIndex = 0;
    [segmentedControl addTarget:self action:@selector(segmentChanged:) forControlEvents: UIControlEventValueChanged];
    _control = segmentedControl;
    [containerView addSubview:_control];
    [_control setEnabled:NO forSegmentAtIndex:1];
    self.tableView.tableHeaderView = containerView;
}

- (void)segmentChanged:(UISegmentedControl *)control 
{
    //reload the tableview / display spinner
    if (!_loadingStats) { //After initial setup
        if (control.selectedSegmentIndex == 0) { //If all go straight in
            _tableNumber = 1;
            [self.tableView reloadData];
        } else {
            if (self.monthData.count == 9) { //If data ready display it
                _tableNumber = 2;
                [self.tableView reloadData];
            } else { //Else wait then display
                UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
                [spinner startAnimating];
                self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]initWithCustomView:spinner];
                _tableNumber = 0;
                [_control setEnabled:NO forSegmentAtIndex:0];
                [self.tableView reloadData];
                [self loadMonthStats];
            }
        }
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidLoad];

    _tableNumber = 0;
    [self.tableView reloadData];
    [self loadAllStats];
}

- (void)loadAllStats
{
    _loadingStats = 1;

    dispatch_queue_t sqlPersonQueue = dispatch_queue_create("SQL Queue", NULL);
    dispatch_async(sqlPersonQueue, ^{
        //DB setup
        FMDatabase * smsdb = [FMDatabase databaseWithPath:@"/private/var/mobile/Library/SMS/sms.db"];
        smsdb.logsErrors = NO;
        [smsdb open];

        //Determine DB structure (Differs depending on original db ios version)
        FMResultSet *columnNamesSet = [smsdb executeQuery:@"PRAGMA table_info(message)"];
        NSMutableArray* columnNames = [[NSMutableArray alloc] init];
        while ([columnNamesSet next]) {
            [columnNames addObject:[columnNamesSet stringForColumn:@"name"]];
        }

        if ([[[columnNames valueForKey:@"description"] componentsJoinedByString:@" ; "] rangeOfString:@"guid"].location == NSNotFound) {
            _newStructure = NO;
        } else {
            _newStructure = YES;
        }

        if (!_newStructure) {
            //Tell me so i can support the new structure
            dispatch_async(dispatch_get_main_queue(), ^{
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
            //Load needed stats from db
            NSMutableArray *tempData = [[NSMutableArray alloc]initWithCapacity:9];
            int totalTotal = [smsdb intForQuery:@"SELECT COUNT(*) FROM chat_message_join"];
            int totalSent = [smsdb intForQuery:@"SELECT COUNT(*) FROM message where is_from_me = 1"];
            int totalReceived = totalTotal - totalSent;
            
            [tempData addObject:[NSNumber numberWithInt:totalTotal]];
            [tempData addObject:[NSNumber numberWithInt:totalSent]];
            [tempData addObject:[NSNumber numberWithInt:totalReceived]];
            
            if (_isIphone) {
                int SMSTotalTotal = [smsdb intForQuery:@"SELECT COUNT(*) FROM message where service = 'SMS'"];
                int SMSTotalSent = [smsdb intForQuery:@"SELECT COUNT(*) FROM message where is_from_me = 1 AND service = 'SMS'"];
                int SMSTotalReceived = SMSTotalTotal - SMSTotalSent;
                
                [tempData addObject:[NSNumber numberWithInt:SMSTotalTotal]];
                [tempData addObject:[NSNumber numberWithInt:SMSTotalSent]];
                [tempData addObject:[NSNumber numberWithInt:SMSTotalReceived]];
                
                
                int iMessageTotalTotal = [smsdb intForQuery:@"SELECT COUNT(*) FROM message where service = 'iMessage'"];
                int iMessageTotalSent = [smsdb intForQuery:@"SELECT COUNT(*) FROM message where is_from_me = 1 AND service = 'iMessage'"];
                int iMessageTotalReceived = iMessageTotalTotal - iMessageTotalSent;
                
                [tempData addObject:[NSNumber numberWithInt:iMessageTotalTotal]];
                [tempData addObject:[NSNumber numberWithInt:iMessageTotalSent]];
                [tempData addObject:[NSNumber numberWithInt:iMessageTotalReceived]];
            }

            [smsdb close];

            dispatch_async(dispatch_get_main_queue(), ^{
                //Refersh everthing on main thread
                _tableNumber = 1;
                _loadingStats = 0;
                self.allData = tempData;
                [self.tableView reloadData];
                self.navigationItem.rightBarButtonItem = nil;
                [_control setEnabled:YES forSegmentAtIndex:0];
                [_control setEnabled:YES forSegmentAtIndex:1];
            });
        }
    });
}

- (void)loadMonthStats
{
    _loadingStats = 1;

    dispatch_queue_t sqlPersonQueue = dispatch_queue_create("SQL Queue", NULL);
    dispatch_async(sqlPersonQueue, ^{
        //DB setup
        FMDatabase * smsdb = [FMDatabase databaseWithPath:@"/private/var/mobile/Library/SMS/sms.db"];
        smsdb.logsErrors = YES;
        [smsdb open];
        
        if (_newStructure) {
            //Date setup
            unsigned int flags = NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit | NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit;
            NSCalendar* calendar = [NSCalendar currentCalendar];
            [calendar setTimeZone:[NSTimeZone timeZoneWithName:@"GMT"]];
            
            NSDateComponents* components = [calendar components:flags fromDate:[NSDate date]];
            [components setHour:23];
            [components setMinute:59];
            [components setSecond:59];
            NSDate *toDate = [calendar dateFromComponents:components];
            [components setHour:0];
            [components setMinute:0];
            [components setSecond:1];
            NSDate *fromDate = [[calendar dateFromComponents:components]dateByAddingTimeInterval:-2332800];
            
            long now1970 = round([toDate timeIntervalSince1970]);
            long now2001 = round([toDate timeIntervalSinceReferenceDate]);
            long monthAgo1970 = round([fromDate timeIntervalSince1970]);
            long monthAgo2001 = round([fromDate timeIntervalSinceReferenceDate]);
            

            //Get data from db
            NSMutableArray *tempData = [[NSMutableArray alloc]initWithCapacity:9];
            int totalTotal = [smsdb intForQuery:[NSString stringWithFormat:@"SELECT COUNT(*) FROM message WHERE (date between '%ld' AND '%ld') OR (date between '%ld' AND '%ld')", monthAgo1970 , now1970 , monthAgo2001 , now2001]];
            int totalSent = [smsdb intForQuery:[NSString stringWithFormat:@"SELECT COUNT(*) FROM message WHERE is_from_me = 1 AND ((date between '%ld' AND '%ld') OR (date between '%ld' AND '%ld'))", monthAgo1970 , now1970 , monthAgo2001 , now2001]];
            int totalReceived = totalTotal - totalSent;
            
            [tempData addObject:[NSNumber numberWithInt:totalTotal]];
            [tempData addObject:[NSNumber numberWithInt:totalSent]];
            [tempData addObject:[NSNumber numberWithInt:totalReceived]];
            
            if (_isIphone) {
                int SMSTotalTotal = [smsdb intForQuery:[NSString stringWithFormat:@"SELECT COUNT(*) FROM message WHERE service = 'SMS' AND ((date between '%ld' AND '%ld') OR (date between '%ld' AND '%ld'))", monthAgo1970 , now1970 , monthAgo2001 , now2001]];
                int SMSTotalSent = [smsdb intForQuery:[NSString stringWithFormat:@"SELECT COUNT(*) FROM message WHERE service = 'SMS' AND is_from_me = 1 AND ((date between '%ld' AND '%ld') OR (date between '%ld' AND '%ld'))", monthAgo1970 , now1970 , monthAgo2001 , now2001]];
                int SMSTotalReceived = SMSTotalTotal - SMSTotalSent;
                
                [tempData addObject:[NSNumber numberWithInt:SMSTotalTotal]];
                [tempData addObject:[NSNumber numberWithInt:SMSTotalSent]];
                [tempData addObject:[NSNumber numberWithInt:SMSTotalReceived]];
                
                
                int iMessageTotalTotal = totalTotal - SMSTotalTotal;
                int iMessageTotalSent = totalSent - SMSTotalSent;
                int iMessageTotalReceived = iMessageTotalTotal - iMessageTotalSent;
                
                [tempData addObject:[NSNumber numberWithInt:iMessageTotalTotal]];
                [tempData addObject:[NSNumber numberWithInt:iMessageTotalSent]];
                [tempData addObject:[NSNumber numberWithInt:iMessageTotalReceived]];
            }

            [smsdb close];

            dispatch_async(dispatch_get_main_queue(), ^{
                //Update everything on main thread
                _tableNumber = 2;
                _loadingStats = 0;
                self.monthData = tempData;
                [self.tableView reloadData];
                self.navigationItem.rightBarButtonItem = nil;
                [_control setEnabled:YES forSegmentAtIndex:0];
                [_control setEnabled:YES forSegmentAtIndex:1];
            });
        }


    });
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if(_isIphone) {
        return 3;
    } else {
        return 1;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 3;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SMSStatsTVC"];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"SMSStatsTVC"];
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
        default:
            break;
    }

    switch (_tableNumber) {
        case 0:
            cell.detailTextLabel.text = @"";
            break;
        case 1:
            cell.detailTextLabel.text = [(NSNumber *)[self.allData objectAtIndex:((indexPath.section)*3 + indexPath.row)] stringValue];
            break;
        case 2:
            cell.detailTextLabel.text = [(NSNumber *)[self.monthData objectAtIndex:((indexPath.section)*3 + indexPath.row)] stringValue];
            break;
        default:
            break;
    }
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case 0:
            return @"TOTAL";
            break;
        case 1:
            return @"SMS";
            break;
        case 2:
            return @"IMESSAGE";
            break;
        default:
            break;
    }
    return @"";
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
