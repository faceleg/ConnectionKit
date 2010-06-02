//
//  SVDocumentInspector.h
//  Sandvox
//
//  Created by Dan Wood on 2/5/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KSInspectorViewController.h"


@interface SVDocumentInspector : KSInspectorViewController
{
    IBOutlet NSPopUpButton		*oLanguagePopup;
	IBOutlet NSTextField		*oLanguageCodeField;
	
	IBOutlet NSButton *oProButton;	// Really just a button for Google integration ... Equivalent to menu
	IBOutlet NSImageView *oProBadge;
}

- (IBAction)configureComments:(id)sender;
- (IBAction)chooseFavicon:(id)sender;
- (IBAction)chooseBanner:(id)sender;

- (NSArray *)languages;
- (IBAction)languageChosen:(id)sender;

@end
