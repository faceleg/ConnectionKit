//
//  KTFeedbackReporter.m
//  Sandvox
//
//  Created by Dan Wood on 7/7/10.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "KTFeedbackReporter.h"
#import "SVValidatorWindowController.h"
#import "NSData+Karelia.h"

@implementation KTFeedbackReporter

@synthesize attachValidation = _attachValidation;




// n=12345&c=1&ss=1&e=foo@bar.com&s=yo+baby&d=something+goes+here&val=1
- (void)setupQueryParameters:(NSDictionary *)URLQueryParameters;
{
	[super setupQueryParameters:URLQueryParameters];
	NSString *validation = [URLQueryParameters objectForKey:@"val"];
	self.attachValidation = (validation && ![validation isEqualToString:@""] && ![validation isEqualToString:@"0"]);
}

// HTML validation report will be included if the link from the report window is clicked.

- (void) addAttachments:(NSMutableArray *)attachments attachmentOwner:(NSString *)attachmentOwner;
{
	if (self.attachValidation)
	{
		NSString *validationReport = [[SVValidatorWindowController sharedController] validationReportString];
		NSData *stringData = [validationReport dataUsingEncoding:NSUTF8StringEncoding];
		NSData *compressedData = [stringData compressBzip2];
		
		NSString *fileName = [NSString stringWithFormat:@"ValidationReport-%@.html", attachmentOwner];
		if (fileName)
		{
			OBASSERT(![fileName isEqualToString:@""]);
            NSString *compressedName = [fileName stringByAppendingPathExtension:EXTENSION_BZIP];
			
			KSFeedbackAttachment *attachment = [KSFeedbackAttachment attachmentWithFileName:compressedName data:compressedData];
			if (attachment)
			{
				[attachments addObject:attachment];
			}
		}
		
	}
}



@end
