//
//  RichTextElementDelegate.m
//  KTPlugins
//
//  Copyright (c) 2004-2005, Karelia Software. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  *  Redistribution of source code must retain the above copyright notice,
//     this list of conditions and the follow disclaimer.
//
//  *  Redistributions in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//     and/or other material provided with the distribution.
//
//  *  Neither the name of Karelia Software nor the names of its contributors
//     may be used to endorse or promote products derived from this software
//     without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS-IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUR OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//
//  Community Note: This code is distrubuted under a modified BSD License.
//  We encourage you to share your Sandvox Plugins similarly.
//

#import "RichTextElementDelegate.h"

#import "DOM+RichTextElement.h"

#import <SandvoxPlugin.h>
#import <SandvoxPlugin.h>

// TODO: seems like we should be folding all of these imports into something easy for plugins to grab (KTPlugins.h?)
#import <KTDesign.h>
#import <KTMaster.h>
#import <KTMediaContainer.h>
#import <KTAbstractMediaFile.h>
#import <KSPathInfoField.h>

#import <WebKit/WebKit.h>


@interface RichTextElementDelegate (Private)
- (void)convertFileListElement:(DOMHTMLDivElement *)div toImageWithSettingsNamed:(NSString *)settingsName;
//- (NSString *)repairMediaReferencesWithinHTMLString:(NSString *)anHTMLString;
@end


@implementation RichTextElementDelegate

#pragma mark awake

- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewObject
{	
	[super awakeFromBundleAsNewlyCreatedObject:isNewObject];
	
	if ( isNewObject )
	{
		// load some placeholder text into richTextHTML
		// (in the future, maybe randomize between different selections)
		NSBundle *bundle = [NSBundle bundleForClass:[self class]];
		
		NSString *path = nil;
		if ([[self delegateOwner] isKindOfClass:[KTPagelet class]])
		{
			path = [bundle pathForResource:@"loremipsum1" ofType:@"html"]; // use shorter text for a pagelet
		}
		else
		{
			path = [bundle pathForResource:@"loremipsum2" ofType:@"html"];
		}
		
		if ( nil != path )
		{
			NSString *HTMLString = [NSString stringWithContentsOfURL:[NSURL fileURLWithPath:path]];
            [[self delegateOwner] setValue:HTMLString forKey:@"richTextHTML"];
		}
		else
		{
			NSLog(@"%@ unable to locate default placeholder text", [self className]);
		}
	}
}

- (void)awakeFromDragWithDictionary:(NSDictionary *)aDictionary
{
	[super awakeFromDragWithDictionary:aDictionary];
	
    NSString *filePath = [aDictionary valueForKey:kKTDataSourceFilePath];
	if ( nil != filePath )
	{
		// check UTI to make sure it's text/rich text
		NSString *aUTI = [NSString UTIForFileAtPath:filePath];	// takes account as much as possible
		if ([NSString UTI:aUTI conformsToUTI:(NSString *)kUTTypeRTF] || 
			[NSString UTI:aUTI conformsToUTI:(NSString *)kUTTypeFlatRTFD] ||
			[NSString UTI:aUTI conformsToUTI:(NSString *)kUTTypeRTFD] ||
			[NSString UTI:aUTI conformsToUTI:(NSString *)kUTTypePlainText] ||
			[NSString UTI:aUTI conformsToUTI:(NSString *)kUTTypeText] ||
			[NSString UTI:aUTI conformsToUTI:@"com.microsoft.word.doc"])
		{
			NSDictionary *docAttributes = nil;
			[self loadContentsFromFile:filePath documentAttributes:&docAttributes];
			//LOG((@"docAttributes = %@", docAttributes));
			
			id owner = [self delegateOwner];
			if ([owner isKindOfClass:[KTPage class]])
			{
				// help set some properties on the page
				KTPage *page = (KTPage *)owner;
				
				NSString *title = [docAttributes objectForKey:NSTitleDocumentAttribute];
				if (title)
				{
					[page setTitleText:title];
				}
				
// TODO: re-enable keyword support once model stabilizes				
//				NSArray *keywords = [docAttributes objectForKey:NSKeywordsDocumentAttribute];
//				if (keywords)
//				{
//					KTStoredArray *saKeywords = [KTStoredArray arrayWithArray:keywords
//													 inManagedObjectContext:(KTManagedObjectContext *)[page managedObjectContext]
//																   entityName:@"KeywordsArray"];
//                    [page setKeywords:saKeywords];
//				}
			}
		}
	}
	else
	{
		NSPasteboard *pboard = [aDictionary objectForKey:kKTDataSourcePasteboard];
		
		NSData *data;
		NSString *string;
		NSAttributedString *attrString = nil;
		
		if ( (nil != [pboard availableTypeFromArray:[NSArray arrayWithObject:NSRTFDPboardType]])
			&& (nil != (data = [pboard dataForType:NSRTFDPboardType])) )
		{
			attrString = [[[NSAttributedString alloc] initWithRTFD:data documentAttributes:nil] autorelease];
			
			NSFileWrapper *fileWrapper = [attrString RTFDFileWrapperFromRange:NSMakeRange(0, [attrString length]) 
														   documentAttributes:nil];
			filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"sandvox_dropped_text.rtfd"];
			[fileWrapper writeToFile:filePath 
						  atomically:NO 
					 updateFilenames:NO];
			[self loadContentsFromFile:filePath 
					documentAttributes:nil];	// no doc attributes
		}
		else if ( (nil != [pboard availableTypeFromArray:[NSArray arrayWithObject:NSRTFPboardType]])
				 && (nil != (data = [pboard dataForType:NSRTFPboardType])) )
		{
			attrString = [[[NSAttributedString alloc] initWithRTF:data documentAttributes:nil] autorelease];
			[self loadContentsFromAttributedString:attrString];
		}
		else if ( (nil != [pboard availableTypeFromArray:[NSArray arrayWithObject:NSStringPboardType]])
				 && (nil != (string = [pboard stringForType:NSStringPboardType])) )
		{
			attrString = [NSAttributedString systemFontStringWithString:string];
			[self loadContentsFromAttributedString:attrString];
		}
	}
}

#pragma mark dealloc

- (void)dealloc
{
	[myRTFDImporter release]; myRTFDImporter = nil;
	[super dealloc];
}

#pragma mark media management

- (NSSet *)requiredMediaIdentifiers
{
	NSMutableSet *result = [NSMutableSet set];
	
	// scan for svxmedia:// URLs, returning set of media identifiers
	NSString *svxString = @"<img src=\"svxmedia://";

	NSString *richTextHTML = [[self delegateOwner] valueForKey:@"richTextHTML"];
	LOG((@"scanning block for identifiers: \n%@", richTextHTML));
	if ( [richTextHTML length] > [svxString length] )
	{
		NSScanner *scanner = [NSScanner scannerWithString:richTextHTML];
		while ( ![scanner isAtEnd] )
		{
			if ( [scanner scanUpToString:svxString intoString:NULL] )
			{
				if ( [scanner scanString:svxString intoString:NULL] )
				{
					NSString *mediaPath = nil;
					if ( [scanner scanUpToString:@"\"" intoString:&mediaPath] )
					{
						NSString *mediaIdentifier = [mediaPath lastPathComponent];
						[result addObject:mediaIdentifier];
					}
				}
			}
		}
	}
	
	return result;
}

#pragma mark content loading

- (void)loadContentsFromFile:(NSString *)aPath documentAttributes:(NSDictionary **)dict
{
	if ( nil == myRTFDImporter )
	{
		myRTFDImporter = [[KTRTFDImporter alloc] init];
	}
	NSString *HTMLString = [myRTFDImporter importWithContentsOfFile:aPath documentAttributes:dict requestor:[self delegateOwner]];
	[[self delegateOwner] setValue:HTMLString forKey:@"richTextHTML"];
}

- (void)loadContentsFromAttributedString:(NSAttributedString *)anAttrString
{
	if ( nil == myRTFDImporter )
	{
		myRTFDImporter = [[KTRTFDImporter alloc] init];
	}
	NSString *HTMLString = [myRTFDImporter importWithAttributedString:anAttrString requestor:[self delegateOwner]];
	[[self delegateOwner] setValue:HTMLString forKey:@"richTextHTML"];
}

#pragma mark -
#pragma mark Page Usage

- (NSString *)summaryHTMLKeyPath
{
	return @"richTextHTML";
}

- (BOOL)summaryHTMLIsEditable { return YES; }

#pragma mark live DOM manipulation

/*	Called when the user tries to paste or drop something into our text.
 *	We want to convert <img> tags and file:// URLs to media containers.
 *
 *	There's 2 types of HTML we can be given. If the user dragged a file, it's a series of divs with the URL text:
 *		<div>file:///somefile.png</div><div>file:///otherfile.png</div>
 *
 *	Anything more complicated and WebKit will provide proper <img> tags. However, they use a custom URL scheme that we
 *	have to manually retrieve the data from. It could look like this:
 *		<p><img src="webkit-fake-url://123456-1234-123456-1234/image.tiff /></p>
 */
- (BOOL)plugin:(KTAbstractElement *)plugin
	shouldInsertNode:(DOMNode *)node
  intoTextForKeyPath:(NSString *)keyPath
		 givenAction:(WebViewInsertAction)action
{
	// TODO: improve on this by looking at UTI and creating OBJECT elements for .mov files, etc.
	
	
	// Figure out the maximum image size we'll allow
	KTAbstractElement *container = [self delegateOwner];
	NSString *settings = nil;
	if ([container isKindOfClass:[KTPagelet class]])
	{
		settings = @"sidebarImage";
	}
	else if ([container isKindOfClass:[KTPage class]])
	{
		// TODO: could we vary the size based on whether the page is showing a sidebar?
		settings = @"inTextMediumImage";
	}
	else
	{
		return NO;
	}
	
	
	// Adjust the node according to which of the above schema it follows
	if ([node isFileList])
	{
		DOMNodeList *divs = [node childNodes];
		unsigned i;
		for (i=0; i<[divs length]; i++)
		{
			[self convertFileListElement:(DOMHTMLDivElement *)[divs item:i] toImageWithSettingsNamed:settings];
		}
	}	
	else
	{
		[node convertImageSourcesToUseSettingsNamed:settings forPlugin:[self delegateOwner]];
	}
	
	return YES;
}

- (void)convertFileListElement:(DOMHTMLDivElement *)div toImageWithSettingsNamed:(NSString *)settingsName;
{
	// TODO: what happens when the default design size changes?
	DOMNode *node = [div parentNode];
		
	// Create a media container for the file
	NSString *path = [[NSURL URLWithString:[(DOMText *)[div firstChild] data]] path];
	KTMediaContainer *mediaContainer = [[self mediaManager] mediaContainerWithPath:path];
	
	
	if ([NSString UTI:[NSString UTIForFileAtPath:path] conformsToUTI:(NSString *)kUTTypeImage])
	{
		// Convert image files to a simple <img> tag
		mediaContainer = [mediaContainer imageWithScalingSettingsNamed:settingsName forPlugin:[self delegateOwner]];
		
		DOMHTMLImageElement *imageElement = (DOMHTMLImageElement *)[[node ownerDocument] createElement:@"IMG"];
		[imageElement setSrc:[[mediaContainer URIRepresentation] absoluteString]];
		[imageElement setAlt:[[path lastPathComponent] stringByDeletingPathExtension]];
		
		[node replaceChild:imageElement :div];
	}
	else
	{
		// Other files are converted to their thumbnail and made a download link
		KTMediaContainer *icon =
			[mediaContainer imageWithScalingSettingsNamed:@"thumbnailImage" forPlugin:[self delegateOwner]];
		
		DOMHTMLImageElement *imageElement = (DOMHTMLImageElement *)[[node ownerDocument] createElement:@"IMG"];
		[imageElement setSrc:[[icon URIRepresentation] absoluteString]];
		[imageElement setAlt:[[path lastPathComponent] stringByDeletingPathExtension]];
		
		DOMHTMLAnchorElement *anchor = (DOMHTMLAnchorElement *)[[node ownerDocument] createElement:@"a"];
		[anchor setHref:[[mediaContainer URIRepresentation] absoluteString]];
		[anchor appendChild:imageElement];
		
		[node replaceChild:anchor :div];	
	}
}

#pragma mark spotlight support

- (NSString *)spotlightHTML
{
	// we don't need to process anything here, just return the raw HTML
	NSString *result = [[self delegateOwner] valueForKey:@"richTextHTML"];
	
	if ( nil == result )
	{
		result = @"";
	}
	
	return result;
}

#pragma mark 1.2.* media reference support

// TODO: 1.2 -> 1.5 file conversion will need to find all ?ref=<refname> and change them into ?id=<uuid>
// look at -repairMediaReferencesWithinHTMLString: in 1.2.1 branch
    
@end
