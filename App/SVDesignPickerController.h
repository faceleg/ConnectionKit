//
//  SVDesignPickerController.h
//  Sandvox
//
//  Created by Terrence Talbot on 8/28/09.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MGScopeBarDelegateProtocol.h"

@class KTDesign;
@class SVDesignBrowserViewController;
@class SVDesignsController;

#if MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_5
@protocol NSWindowDelegate <NSObject> @end
#endif


@interface SVDesignPickerController : NSViewController <NSWindowDelegate, MGScopeBarDelegate>
{
    IBOutlet MGScopeBar             *oScopeBar;
	
  @private
    KTDesign    *_design;
    
    NSWindow                        *_window;
    SVDesignsController             *_designsController;
    BOOL    _loading;
    SVDesignBrowserViewController   *_browserViewController;
    
    NSString *_genre;
	NSString *_color;
	NSString *_width;
	
	BOOL _hasNullWidth;
	BOOL _hasNullColor;
	BOOL _hasNullGenre;

	SEL _selectorWhenChosen;
	id	_targetWhenChosen;		// weak to avoid retain cycle
}

@property (nonatomic, retain) KTDesign *design;
@property (nonatomic, copy) NSString *genre;
@property (nonatomic, copy) NSString *color;
@property (nonatomic, copy) NSString *width;
@property (nonatomic, readonly) NSString *matchString;

@property (nonatomic, retain) IBOutlet NSWindow *window;
@property (nonatomic, retain) IBOutlet NSArrayController *designsController;

@property (nonatomic, retain) IBOutlet SVDesignBrowserViewController *browserViewController;
- (BOOL)isBrowserViewControllerLoaded;

- (IBAction)cancelSheet:(id)sender;
- (IBAction)chooseDesign:(id)sender;
- (IBAction) windowHelp:(id)sender;

// Selector should take the form -designChooserDidEnd:returnCode:
- (void)beginDesignChooserForWindow:(NSWindow *)window delegate:(id)aTarget didEndSelector:(SEL)aSelector;
- (void)beginWithDelegate:(id)aTarget didEndSelector:(SEL)aSelector;

@end
