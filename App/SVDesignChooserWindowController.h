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
@interface SVDesignChooserWindowController : NSWindowController <MGScopeBarDelegate>
{
    IBOutlet SVDesignChooserViewController   *oViewController;
    IBOutlet MGScopeBar             *oScopeBar;
	
	NSArray *_allDesigns;
	NSString *_genre;
	NSString *_color;
	
	SEL _selectorWhenChosen;
	id	_targetWhenChosen;		// weak to avoid retain cycle
}

@property(nonatomic, retain) KTDesign *design;

@property(copy) NSArray *allDesigns;

@property(assign) SEL selectorWhenChosen;
@property(assign) id  targetWhenChosen;
@property(retain) SVDesignChooserViewController *viewController;
@property (copy) NSString *genre;
@property (copy) NSString *color;
@property (readonly) NSString *noMatchString;

- (IBAction)cancelSheet:(id)sender;
- (IBAction)chooseDesign:(id)sender;

- (void)beginSheetModalForWindow:(NSWindow *)window delegate:(id)aTarget didEndSelector:(SEL)aSelector;

@end
