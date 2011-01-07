//
//  SVDocumentInspector.h
//  Sandvox
//
//  Created by Dan Wood on 2/5/10.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KSInspectorViewController.h"


@class SVFillController, SVBannerPickerController;


@interface SVDocumentInspector : KSInspectorViewController
{
    IBOutlet NSPopUpButton		*oLanguagePopup;
	IBOutlet NSTextField		*oLanguageCodeField;
    
    IBOutlet SVBannerPickerController   *oBannerPickerController;
    IBOutlet SVFillController           *oFaviconPickerController;
	
	IBOutlet NSButton *oProButton;	// Really just a button for Google integration ... Equivalent to menu
}

- (NSArray *)languages;
- (IBAction)languageChosen:(id)sender;

@end
