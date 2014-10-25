//
//  CRViewController.m
//
//  Created by Callum Ryan on 28/10/2013.
//
//

#import "CRViewController.h"
#import "CRStatsProvider.h"
#import "FMDB.h"

@interface CRViewController () {
    NSString *_name;
    NSString *_guid;
    BOOL _gotData;
}

@property (nonatomic, strong) NSArray *data;

- (void)loadStats;
@end

@implementation CRViewController

@synthesize data = _data;

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
        self.data = [CRStatsProvider statsForGuid:_guid];
        dispatch_async(dispatch_get_main_queue(), ^{
            _gotData = 1;
            [self.tableView reloadData];
            self.navigationItem.rightBarButtonItem = nil;
        });
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
