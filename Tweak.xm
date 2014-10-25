//Headers
#import <UIKit/UIKit.h>

#import "CRViewController.h"
#import "CRViewControllerAll.h"
#import "CRStatsProvider.h"

//Headers iOS 7 
@interface UIImage(Extras)
+ (UIImage *)imageNamed:(NSString *)name inBundle:(NSBundle *)bundle;
@end

@interface CKConversation
@property(retain, nonatomic) id chat;
@property(readonly, assign, nonatomic) NSString* name;
@end

@interface CKConversationListController
@property(nonatomic, assign) UINavigationItem *navigationItem;
- (UINavigationController *)navigationController;
@end

@interface CKTranscriptController
- (NSString *)title;
- (UINavigationController *)navigationController;
@end

@interface CKMultipleRecipientTableViewCell : UIView{
	NSMutableArray *_visibleButtons;
}
- (UIView *)contentView;
@property (assign,nonatomic) BOOL showMailButton;                  
@property (assign,nonatomic) BOOL showPhoneButton;                   
@property (assign,nonatomic) BOOL showFaceTimeVideoButton; 
@end

//Headers iOS8
@interface CKTranscriptRecipientsController : UITableViewController 
- (void)loadStats;
@end

@interface CKTranscriptRecipientsHeaderFooterView  : UITableViewHeaderFooterView
@property(retain) UILabel * headerLabel;
@property(retain) UILabel * preceedingSectionFooterLabel;
@end

//Shared
#define bundlePath @"/Library/Application Support/SMSStats2.bundle"

//Global vars
UIBarButtonItem *_topButton = nil;

//Hook to add button on conversation list view
%hook CKConversationListController
- (void)viewWillAppear:(BOOL)arg1
{
	%orig;

	NSMutableArray *array = [NSMutableArray arrayWithArray:self.navigationItem.rightBarButtonItems];

	if (![array containsObject:_topButton]) {
		UIButton *newButton = [UIButton buttonWithType:UIButtonTypeCustom]; 
		UIImage *image = [UIImage imageNamed:@"statsImg.png" inBundle:[[NSBundle alloc] initWithPath:bundlePath]];

		[newButton setImage:image forState:UIControlStateNormal];
		newButton.showsTouchWhenHighlighted = YES;
		[newButton addTarget:self action:@selector(buttonPressed:) forControlEvents:UIControlEventTouchUpInside];
		[newButton setFrame:CGRectMake(0 ,0 , 36 , 36)];
		_topButton  = [[UIBarButtonItem alloc] initWithImage:image style:UIBarButtonItemStylePlain target:self action:@selector(statsButtonPressed:)];

		NSMutableArray *array = [NSMutableArray arrayWithArray:self.navigationItem.rightBarButtonItems];
		[array addObject:_topButton];
		self.navigationItem.rightBarButtonItems = array;
    }

}

%new(v@:)
- (void)statsButtonPressed:(id)sender //Push VC
{
	[[self navigationController] pushViewController:[[CRViewControllerAll alloc]init] animated:YES];
}
%end

//iOS 7

//Class stub
@interface statsButton : UIButton		@end
@implementation statsButton			@end


//Global vars
CKTranscriptController *transcriptController = nil;
NSMutableArray *contactButtons = [[NSMutableArray alloc] init];
BOOL isBiteSMS = NO;

//In thread button setup
%hook CKMultipleRecipientTableViewCell
- (void)layoutSubviews //Correct frame
{
	%orig;

	for (statsButton *button in contactButtons) {
    	if ([button isKindOfClass:[statsButton class]]) {
    		//Correct positioning
    		if (isBiteSMS) {
			[button setFrame:CGRectMake(self.frame.size.width - (MSHookIvar<NSMutableArray *>(self, "_visibleButtons").count * 40) ,7 , 36 , 36)];
    		} else {
			[button setFrame:CGRectMake(self.frame.size.width - (MSHookIvar<NSMutableArray *>(self, "_visibleButtons").count * 40) ,4 , 36 , 36)];
    		}
    	}
    }
}

- (NSMutableArray *)visibleButtons //Add button if needed with correct frame
{
	NSMutableArray *visibleButtons = %orig;

	BOOL needToAdd = YES;
	for (UIView *subview in visibleButtons) {
		if ([subview isKindOfClass:[statsButton class]]) {
			needToAdd = NO;
		}
	}
 
 	if (needToAdd) {
 		statsButton *button = [statsButton buttonWithType:UIButtonTypeCustom];
		if (isBiteSMS) {
			button.frame = CGRectMake(self.frame.size.width - (MSHookIvar<NSMutableArray *>(self, "_visibleButtons").count * 40) ,7 , 36 , 36);
		} else {
			button.frame = CGRectMake(self.frame.size.width - (MSHookIvar<NSMutableArray *>(self, "_visibleButtons").count * 40) ,4 , 36 , 36);
		}
 		[visibleButtons addObject:button];
 	}

 	return visibleButtons;
}

- (id)initWithStyle:(int)arg1 reuseIdentifier:(id)arg2 //Fix layout of button
{
	//biteSMS cheack (different positioning needed)
	isBiteSMS = [[NSFileManager defaultManager] fileExistsAtPath:@"/Applications/biteSMS.app"];

	CKMultipleRecipientTableViewCell *originalTVC = (CKMultipleRecipientTableViewCell *)%orig(arg1,arg2);

	//create button
	statsButton *newButton = [statsButton buttonWithType:UIButtonTypeSystem]; 
	UIImage *image = [UIImage imageNamed:@"statsImg.png" inBundle:[[NSBundle alloc] initWithPath:bundlePath]];
	[newButton setImage:image forState:UIControlStateNormal];
	[newButton addTarget:self action:@selector(statsButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
	newButton.frame = CGRectMake(-40,4 , 36 , 36);
	newButton.adjustsImageWhenHighlighted = NO;

	//add button
	[contactButtons addObject:newButton];
	[originalTVC.contentView addSubview:newButton];

	return originalTVC;
}

%new(v@:)
- (void)statsButtonPressed:(id)sender //Push vc with info
{
	CKConversation *conversation = MSHookIvar<CKConversation *>(transcriptController, "_conversation");
	NSString *guid = MSHookIvar<NSString *>(conversation.chat, "_guid");
	
	[[transcriptController navigationController]pushViewController:[[CRViewController alloc]initWithName:conversation.name guid:guid] animated:YES];
}
%end

//hook for controller pointer
%hook CKTranscriptController
- (void)viewDidAppear:(BOOL)arg1
{
	%orig(arg1);

	transcriptController = self;
}
%end

//iOS 8 
//globals
NSString *_name = nil;
NSString *_guid = nil;
BOOL _gotData = NO;
NSArray *data = nil;


%hook CKTranscriptRecipientsController
- (NSInteger)numberOfSectionsInTableView:(id)tableView
{
	NSInteger original = %orig;
	return original + 1;
}

- (NSInteger)tableView:(id)tableView numberOfRowsInSection:(NSInteger)section
{
	if (section == ([self numberOfSectionsInTableView:tableView]-1)) {
		return 3;
	}
	return %orig;
}

- (id)tableView:(id)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section == ([self numberOfSectionsInTableView:tableView]-1)) {
		static NSString *CellIdentifier = @"Cell";

		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
		if (cell == nil) {
		    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
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
	        cell.detailTextLabel.text = [(NSNumber *)[data objectAtIndex:indexPath.row] stringValue];
	    } else {
	        cell.detailTextLabel.text = @"";
	    }


		return cell;
	} 
	return %orig;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (indexPath.section == ([self numberOfSectionsInTableView:tableView]-1)) {
		return 44.0;
	} 
	return %orig;
}

- (BOOL)tableView:(UITableView *)tableView shouldShowMenuForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section == ([self numberOfSectionsInTableView:tableView]-1)) {
		return YES;
	} 
    return %orig;
}

- (BOOL)tableView:(UITableView *)tableView canPerformAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender
{
    if (action == @selector(copy:) && indexPath.section == ([self numberOfSectionsInTableView:tableView]-1)) {
    	return YES;
    }
    return %orig;
}

- (void)tableView:(UITableView *)tableView performAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender
{
    if (action == @selector(copy:) && indexPath.section == ([self numberOfSectionsInTableView:tableView]-1)) {
        //copy cell detail to pasteboard
        UITableViewCell *cell = [self tableView:tableView cellForRowAtIndexPath:indexPath];
        [[UIPasteboard generalPasteboard] setString:cell.detailTextLabel.text];
    } else {
    	%orig;
    }
}

-(void)viewWillAppear:(BOOL)animated
{
    %orig;

	CKConversation *conversation = MSHookIvar<CKConversation *>(self, "_conversation");
	_guid = MSHookIvar<NSString *>(conversation.chat, "_guid");
	[self loadStats];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
	if (section == ([self numberOfSectionsInTableView:tableView]-1)) {
		return nil;
	} 
	if (section == ([self numberOfSectionsInTableView:tableView]-2)) {
		CKTranscriptRecipientsHeaderFooterView *original = %orig;
		original.headerLabel.text = @"STATISTICS";
		return original;
	} 
	return %orig;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
	if (section == ([self numberOfSectionsInTableView:tableView]-1)) {
		UIView *view = [[UIView alloc]initWithFrame:CGRectMake(0,0,2000,50)];
		view.backgroundColor = [UIColor colorWithRed:0.922 green:0.922 blue:0.922 alpha:1];
		UIView *view2 = [[UIView alloc]initWithFrame:CGRectMake(0,0,2000,0.5)];
		view2.backgroundColor = [UIColor colorWithRed:0.737255 green:0.737255 blue:0.737255 alpha:1];
		[view addSubview:view2];
		return view;
	}
	return %orig;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
	if (section == ([self numberOfSectionsInTableView:tableView]-2)) {
		return 70.0;
	} 
	return %orig;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
	if (section == ([self numberOfSectionsInTableView:tableView]-1)) {
		return 50.0;
	} 
	return %orig;
}

%new(v@:)
- (void)loadStats
{
	dispatch_queue_t sqlPersonQueue = dispatch_queue_create("SQL Queue", NULL);
	dispatch_async(sqlPersonQueue, ^{
		data = [CRStatsProvider statsForGuid:_guid];
	    dispatch_async(dispatch_get_main_queue(), ^{
	        _gotData = YES;
	        NSLog(@"data: %@",data);
			[self.tableView reloadSections:[NSIndexSet indexSetWithIndex:([self numberOfSectionsInTableView:self.tableView]-1)] withRowAnimation:UITableViewRowAnimationNone];
	    });
	});
}
%end