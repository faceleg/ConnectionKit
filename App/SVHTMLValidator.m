//
//  SVHTMLValidator.m
//  Sandvox
//
//  Created by Mike on 30/11/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVHTMLValidator.h"

#import "KTPage.h"

#import "KSHTMLWriter.h"


@implementation SVHTMLValidator

+ (ValidationState)validateHTMLString:(NSString *)html docType:(NSString *)docType error:(NSError **)outError;
{
    ValidationState result;
    
    // Use NSXMLDocument -- not useful for errors, but it's quick.
    NSXMLDocument *xmlDoc = [[NSXMLDocument alloc] initWithXMLString:html
                             // Don't try to actually validate HTML; it's not XML
                                                             options:(![KSHTMLWriter isDocTypeXHTML:docType]) ? NSXMLDocumentTidyHTML|NSXMLNodePreserveAll : NSXMLNodePreserveAll
                                                               error:outError];
    
    if (xmlDoc)
    {
        // Don't really try to validate if it's HTML 5.  Don't have a DTD!
        // Don't really validate if it's HTML  ... We were having problems loading the DTD.
        if ([KSHTMLWriter isDocTypeXHTML:docType] && ![docType isEqualToString:KSHTMLWriterDocTypeHTML_5])
        {
            // Further check for validation if we can
            BOOL valid = [xmlDoc validateAndReturnError:outError];
            result = valid ? kValidationStateLocallyValid : kValidationStateValidationError;
        }
        else	// no ability to validate further, so assume it's locally valid.
        {
            result = kValidationStateLocallyValid;
        }
        [xmlDoc release];
    }
    else
    {
		// Try parsing more leniantly.
		xmlDoc = [[NSXMLDocument alloc] initWithXMLString:html
				  // Don't try to actually validate HTML; it's not XML
												  options:NSXMLDocumentTidyHTML|NSXMLNodePreserveAll
													error:outError];
		if (xmlDoc)
		{
			result = kValidationStateValidationError;		// indicate some sort of error since it didn't work the first non-tidy pass.
			[xmlDoc release];
		}
		else
		{
			result = kValidationStateUnparseable;
		}
    }
        
    return result;
}

+ (NSString *)HTMLStringWithFragment:(NSString *)fragment docType:(NSString *)docType;
{
    OBPRECONDITION(fragment);
    
    NSString *title			= @"<title>This is a piece of HTML, wrapped in some markup to help the validator</title>";
	NSString *commentStart	= @"<!-- BELOW IS THE HTML THAT YOU SUBMITTED TO THE VALIDATOR -->";
	
	NSString *localDTD  = [KTPage stringFromDocType:docType local:YES];
    
	// Special adjustments for local validation on HTML4.
	// Don't use the DTD if It's HTML 4 ... I was getting an error on local validation.
	// With no DTD, validation seems OK in the local validation.
	// And close the meta tag, too.
	if (![KSHTMLWriter isDocTypeXHTML:docType])
	{
		localDTD = @"";
	}
	// NOTE: If we change the line count of the prelude, we will have to adjust the start= value in -[SVValidatorWindowController validateSource:...]
    
	NSString *metaCharset = nil;
	NSString *htmlStart = nil;
    
	if (![KSHTMLWriter isDocTypeXHTML:docType])
	{
			htmlStart	= @"<html lang=\"en\">";
			metaCharset = @"<meta http-equiv=\"content-type\" content=\"text/html; charset=UTF-8\">";
    }
    else
    {
		if ([docType isEqualToString:KSHTMLWriterDocTypeHTML_5])
        {
			htmlStart	= @"<html xmlns=\"http://www.w3.org/1999/xhtml\" xml:lang=\"en\" lang=\"en\">";	// same as XHTML ?
			metaCharset = @"<meta charset=\"UTF-8\" />";
		}
		else
        {
			htmlStart	= @"<html xmlns=\"http://www.w3.org/1999/xhtml\" xml:lang=\"en\" lang=\"en\">";
			metaCharset = @"<meta http-equiv=\"content-type\" content=\"text/html; charset=UTF-8\" />";
		}
	}
	
	NSMutableString *result = [NSMutableString stringWithFormat:
                                            @"%@\n%@\n<head>\n%@\n%@\n</head>\n<body>\n%@\n",
                                            localDTD,
                                            htmlStart,
                                            metaCharset,
                                            title,
                                            commentStart];
	
    
    
	[result appendString:fragment];
	[result appendString:@"\n<!-- ABOVE IS THE HTML THAT YOU SUBMITTED TO THE VALIDATOR -->\n</body>\n</html>\n"];
	return result;
}

@end


#pragma mark -


@implementation SVRemoteHTMLValidator

+ (NSString *)HTMLStringWithFragment:(NSString *)fragment docType:(NSString *)docType;
{
    NSString *title			= @"<title>This is a piece of HTML, wrapped in some markup to help the validator</title>";
	NSString *commentStart	= @"<!-- BELOW IS THE HTML THAT YOU SUBMITTED TO THE VALIDATOR -->";
	
	NSString *remoteDTD = [KTPage stringFromDocType:docType local:NO];
    
	// NOTE: If we change the line count of the prelude, we will have to adjust the start= value in -[SVValidatorWindowController validateSource:...]
    
	NSString *metaCharset = nil;
	NSString *htmlStart = nil;
	
    if (![KSHTMLWriter isDocTypeXHTML:docType])
	{
        htmlStart	= @"<html lang=\"en\">";
        metaCharset = @"<meta http-equiv=\"content-type\" content=\"text/html; charset=UTF-8\">";
    }
    else
    {
		if ([docType isEqualToString:KSHTMLWriterDocTypeHTML_5])
        {
			htmlStart	= @"<html xmlns=\"http://www.w3.org/1999/xhtml\" xml:lang=\"en\" lang=\"en\">";	// same as XHTML ?
			metaCharset = @"<meta charset=\"UTF-8\" />";
		}
		else
        {
			htmlStart	= @"<html xmlns=\"http://www.w3.org/1999/xhtml\" xml:lang=\"en\" lang=\"en\">";
			metaCharset = @"<meta http-equiv=\"content-type\" content=\"text/html; charset=UTF-8\" />";
		}
	}
	
	NSMutableString *result = [NSMutableString stringWithFormat:
                                @"%@\n%@\n<head>\n%@\n%@\n</head>\n<body>\n%@\n",
                                remoteDTD,
                                htmlStart,
                                metaCharset,
                                title,
                                commentStart];
    
    
    [result appendString:fragment];
	[result appendString:@"\n<!-- ABOVE IS THE HTML THAT YOU SUBMITTED TO THE VALIDATOR -->\n</body>\n</html>\n"];
	return result;
}

@end
