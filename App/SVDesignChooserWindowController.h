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
    SVDesignChooserViewController   *_viewController;
    IBOutlet MGScopeBar             *oScopeBar;
    IBOutlet NSBox                 *oTargetView;
    
    KTDesign                        *_selectedDesign;
}

@property(retain) SVDesignChooserViewController *viewController;
@property(retain) KTDesign *selectedDesign;

- (void)displayAsSheet;
- (IBAction)cancelSheet:(id)sender;
- (IBAction)chooseDesign:(id)sender;

@end
