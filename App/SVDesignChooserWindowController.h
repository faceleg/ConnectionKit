//
//  SVDesignChooserWindowController.h
//  Sandvox
//
//  Created by Terrence Talbot on 8/28/09.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SVDesignChooserViewController;
@class KTDesign;
@interface SVDesignChooserWindowController : NSWindowController 
{
    SVDesignChooserViewController   *viewController_;
    IBOutlet NSView                 *oTargetView;
    
    KTDesign                        *selectedDesign_;
}

@property(retain) SVDesignChooserViewController *viewController;
@property(retain) KTDesign *selectedDesign;

- (void)displayAsSheet;
- (IBAction)cancelSheet:(id)sender;
- (IBAction)chooseDesign:(id)sender;

@end
