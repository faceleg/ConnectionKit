//
//  SVPageInspector.h
//  Sandvox
//
//  Created by Mike on 06/01/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "KSInspectorViewController.h"

#import "KTPage.h"
#import "SVPageThumbnailHTMLContext.h"


@class KTPlaceholderBindingTextField, SVSidebarPageletsController, SVPageThumbnailController, SVSiteItemController, SVTruncationController;


@interface SVPageInspector : KSInspectorViewController <SVPageThumbnailHTMLContextDelegate>
{
    IBOutlet KTPlaceholderBindingTextField  *oMenuTitleField;
    
    IBOutlet SVPageThumbnailController  *oThumbnailController;
    IBOutlet SVSiteItemController       *oSiteItemController;
	IBOutlet SVTruncationController		*oTruncationController;
    IBOutlet NSPopUpButton              *oThumbnailPicker;
    
    IBOutlet NSButton *showTimestampCheckbox;
    
    IBOutlet SVSidebarPageletsController    *oSidebarPageletsController;
    IBOutlet NSTableView                    *oSidebarPageletsTable;
    
    IBOutlet NSButton   *_convertToCollectionButton;
    IBOutlet NSButton   *_convertToRegularPageButton;
}

- (IBAction)chooseNavigationArrowsStyle:(NSPopUpButton *)sender;

- (IBAction)toggleComments:(NSButton *)sender;

- (IBAction)selectTimestampType:(NSPopUpButton *)sender;

- (IBAction)pickThumbnailFromPage:(NSPopUpButton *)sender;
- (void)updatePickFromPageThumbnail;

- (IBAction)toggledArchives:(NSButton *)sender;

@end
