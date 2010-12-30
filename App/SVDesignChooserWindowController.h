//
//  SVDesignChooserWindowController.h
//  Sandvox
//
//  Created by Terrence Talbot on 8/28/09.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MGScopeBarDelegateProtocol.h"

@class KTDesign;
@class SVDesignChooserViewController;
@class SVDesignsController;

@interface SVDesignChooserWindowController : NSWindowController <MGScopeBarDelegate>
{
    IBOutlet MGScopeBar             *oScopeBar;
	
  @private
    SVDesignsController             *_designsController;
    SVDesignChooserViewController   *_viewController;
    
    NSString *_genre;
	NSString *_color;
	NSString *_width;
	
	BOOL _hasNullWidth;
	BOOL _hasNullColor;
	BOOL _hasNullGenre;

	SEL _selectorWhenChosen;
	id	_targetWhenChosen;		// weak to avoid retain cycle
}

@property(nonatomic, retain) KTDesign *design;
@property (copy) NSString *genre;
@property (copy) NSString *color;
@property (copy) NSString *width;
@property (readonly) NSString *matchString;

@property(nonatomic, retain) IBOutlet NSArrayController *designsController;
@property(nonatomic, retain) IBOutlet SVDesignChooserViewController *viewController;

- (IBAction)cancelSheet:(id)sender;
- (IBAction)chooseDesign:(id)sender;

// Selector should take the form -designChooserDidEnd:returnCode:
- (void)beginDesignChooserForWindow:(NSWindow *)window delegate:(id)aTarget didEndSelector:(SEL)aSelector;
- (void)beginWithDelegate:(id)aTarget didEndSelector:(SEL)aSelector;

@end
