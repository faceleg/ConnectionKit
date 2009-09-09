//
//  KTExportSavePanelController.m
//  Marvel
//
//  Created by Mike on 15/12/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KTExportSavePanelController.h"

#import "NSURL+Karelia.h"


@implementation KTExportSavePanelController

- (id)initWithSiteURL:(NSURL *)URL documentURL:(NSURL *)docURL;
{
    if (self = [self initWithNibNamed:@"KTTransfer" bundle:nil])
    {
        _documentURL = [docURL copy];
        
        [self view];    // Make sure the view is loaded
        [oSiteURLField setObjectValue:URL]; // Really this ought to be handled as an ivar
    }
    
    return self;
}

- (void)dealloc
{
    [_documentURL release];
    [super dealloc];
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
- (NSString *)panel:(id)sender userEnteredFilename:(NSString *)filename confirmed:(BOOL)okFlag;
{
	NSSavePanel *panel = sender;
    NSString *result = filename;
    
    if (okFlag)
    {
        // Test the URL is valid
        result = nil;
        NSURL *siteURL = [self siteURL];
        if (siteURL && [siteURL scheme])
        {
            if ([[siteURL scheme] isEqualToString:@"http"] || [[siteURL scheme] isEqualToString:@"https"])
            {
                result = filename;
            }
        }
        
        if (!result) NSBeep();  // you'd think so, but NSSavePanel doesn't do this for us
        
        
        // Don't allow the user to overwrite document or its contents
        if (result)
        {
            NSURL *exportURL = [panel URL];
            NSURL *docURL = _documentURL;
            if ([docURL isSubpathOfURL:exportURL] || [exportURL isSubpathOfURL:docURL])
            {
                result = nil;
                
                NSAlert *alert = [[NSAlert alloc] init];
				[alert setIcon:[NSApp applicationIconImage]];
                [alert setMessageText:NSLocalizedString(@"The site cannot be exported here as that would replace the document.", "Alert title")];
                [alert setInformativeText:NSLocalizedString(@"Choose a different location or file name for the export.", "Alert info")];
                
                [alert beginSheetModalForWindow:panel
                                  modalDelegate:nil
                                 didEndSelector:NULL
                                    contextInfo:NULL];
            }
        }
    }
    
    return result;
} 

@end
