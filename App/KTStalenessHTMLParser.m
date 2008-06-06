//
//  KTStalenessHTMLParser.m
//  Marvel
//
//  Created by Mike on 11/02/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTStalenessHTMLParser.h"
#import "KTHTMLParser+Private.h"

#import "KTWebViewTextBlock.h"


@implementation KTStalenessHTMLParser

/*	Locating localized strings is expensive and there's no point doing it for the staleness manager.
 */
- (NSString *)componentLocalizedString:(NSString *)tag { return @""; }

- (NSString *)componentTargetLocalizedString:(NSString *)tag { return @""; }

- (NSString *)mainBundleLocalizedString:(NSString *)tag { return @""; }


/*	In addition to the usual behaviour, we want to pass out keypaths to the delegate which account for how to thingy
 */
- (KTWebViewTextBlock *)textblockForKeyPath:(NSString *)keypath ofObject:(id)object
									  flags:(NSArray *)flags
								    HTMLTag:(NSString *)tag
						  graphicalTextCode:(NSString *)GTCode
								  hyperlink:(KTAbstractPage *)hyperlink
{
	KTWebViewTextBlock *result =
		[super textblockForKeyPath:keypath ofObject:object flags:flags HTMLTag:tag graphicalTextCode:GTCode hyperlink:hyperlink];
	
	
	if ([result isRichText])
	{
		// Scan through the preview text for page paths
		NSString *HTML = [result innerHTML:kGeneratingPreview];
		NSScanner *scanner = [[NSScanner alloc] initWithString:HTML];
		NSString *searchString = @"<a href=\"";
		NSString *aPagePreviewPath;
		
		while (![scanner isAtEnd])
		{
			// Scan for an anchor
			[scanner scanUpToString:searchString intoString:NULL];
			if ([scanner isAtEnd]) break;
			[scanner setScanLocation:([scanner scanLocation] + [searchString length])];
			
			[scanner scanUpToString:@"\"" intoString:&aPagePreviewPath];
			
			
			// Figure the page corresponding to the path and inform the delegate
			KTPage *page = [[[self currentPage] document] pageForURLPath:aPagePreviewPath];
			if (page)
			{
				[self didEncounterKeyPath:@"URL" ofObject:page];
			}
		}
	}
	
	return result;
}

@end
