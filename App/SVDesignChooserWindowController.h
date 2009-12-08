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
    	
	SEL _selectorWhenChosen;
	id	_targetWhenChosen;		// weak to avoid retain cycle
}

@property(assign) SEL selectorWhenChosen;
@property(assign) id  targetWhenChosen;
@property(retain) SVDesignChooserViewController *viewController;

- (IBAction)cancelSheet:(id)sender;
- (IBAction)chooseDesign:(id)sender;

- (void)displayWithSelectorButIWishWeCouldSpecifyABlock:(SEL)aSelector object:aTarget designWas:(KTDesign *)oldDesign;

@end
