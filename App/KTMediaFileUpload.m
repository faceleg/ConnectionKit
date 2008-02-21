//
//  KTMediaFileUpload.m
//  Marvel
//
//  Created by Mike on 09/12/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "KTMediaFileUpload.h"

#import "KTPage.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSString+KTExtensions.h"


@implementation KTMediaFileUpload

- (NSString *)publishedPathRelativeToPage:(KTPage *)page
{
	NSString *mediaPath = [@"/" stringByAppendingString:[self valueForKey:@"pathRelativeToSite"]];
	NSString *pagePath = [@"/" stringByAppendingString:[page publishedPathRelativeToSite]];
	
	NSString *result = [mediaPath pathRelativeTo:pagePath];
	return result;
}

/*	Make sure that once the path has been set it can't be changed
 */
- (void)setPathRelativeToSite:(NSString *)path
{
	if ([self valueForKey:@"pathRelativeToSite"])
	{
		[NSException raise:NSInvalidArgumentException
					format:@"-[KTMediaFileUpload pathRelativeToSite] is immutable"];
	}
	else
	{
		[self setWrappedValue:path forKey:@"pathRelativeToSite"];
	}
}

@end
