//
//  KTExportSavePanelController.h
//  Marvel
//
//  Created by Mike on 15/12/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KSViewController.h"


@interface KTExportSavePanelController : KSViewController
{
    IBOutlet NSTextField    *oSiteURLField;
}

- (id)initWithSiteURL:(NSURL *)URL;
- (NSURL *)siteURL;

@end
