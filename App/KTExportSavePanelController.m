//
//  KTExportSavePanelController.m
//  Marvel
//
//  Created by Mike on 15/12/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTExportSavePanelController.h"


@implementation KTExportSavePanelController

- (id)initWithSiteURL:(NSURL *)URL
{
    if (self = [self initWithNibNamed:@"KTTransfer" bundle:nil])
    {
        [self view];    // Make sure the view is loaded
        [oSiteURLField setObjectValue:URL]; // Really this ought to be handled as an ivar
    }
    
    return self;
}

/*  Grabs the URL from the accessory view and gives it a http:// scheme if needed
 */
- (NSURL *)siteURL
{
    NSURL *result = [oSiteURLField objectValue];
    if (result && ![result scheme])
    {
        result = [NSURL URLWithString:[@"http://" stringByAppendingString:[result absoluteString]]];
    }
    
    return result;
}

/*  We don't actually care about the filename, but the URL field must contain a valid http or https URL.
 */
- (BOOL)panel:(NSSavePanel *)openPanel isValidFilename:(NSString *)filename
{
	BOOL result = NO;
    
    NSURL *URL = [self siteURL];
    if (URL && [URL scheme])
    {
        if ([[URL scheme] isEqualToString:@"http"] || [[URL scheme] isEqualToString:@"https"])
        {
            result = YES;
        }
    }
    
    if (!result) NSBeep();  // You'd think so, but NSSavePanel doesn't do this for us
    return result;
} 

@end
