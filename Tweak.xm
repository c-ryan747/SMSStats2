#import <UIKit/UIKit.h>

#import "CRViewController.h"
#import "CRViewControllerAll.h"

#define bundlePath @"/Library/Application Support/SMSStats2.bundle"


//Headers
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


//Class stub
@interface statsButton : UIButton		@end
@implementation statsButton				@end


//Global vars
UIBarButtonItem *_topButton = nil;
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


//Hook to add button on conversation list view
%hook CKConversationListController
- (void)viewWillAppear:(BOOL)arg1
{
	%orig(arg1);

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


//hook for controller pointer
%hook CKTranscriptController
- (void)viewDidAppear:(BOOL)arg1
{
	%orig(arg1);

	transcriptController = self;
}
%end













