//
//  RichTextElementDelegate.m
//  Sandvox SDK
//
//  Copyright 2004-2009 Karelia Software. All rights reserved.
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

//  NOTE: No LocalizedStrings in this plugin, so no genstrings build phase needed

#import "RichTextElementDelegate.h"

#import "SandvoxPlugin.h"


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
		
		NSString *path = [bundle pathForResource:@"loremipsum2" ofType:@"html"];
		
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
	NSString *richTextHTML = [[self delegateOwner] valueForKey:@"richTextHTML"];
	NSSet *result = [KTMediaContainer mediaContainerIdentifiersInHTML:richTextHTML];
	
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

#pragma mark -
#pragma mark Data Migrator

- (BOOL)importPluginProperties:(NSDictionary *)oldPluginProperties
                    fromPlugin:(NSManagedObject *)oldPlugin
                         error:(NSError **)error
{
    // Figure out the maximum image size we'll allow
	KTAbstractElement *container = [self delegateOwner];
	NSString *settings = nil;
	if ([container isKindOfClass:[KTPage class]])
	{
		// TODO: could we vary the size based on whether the page is showing a sidebar?
		settings = @"inTextMediumImage";
	}
	
	
	// Update media refs to the new system.
    NSString *oldText = [oldPluginProperties objectForKey:@"richTextHTML"];
    
    NSString *newText = [[self mediaManager] importLegacyMediaFromString:oldText
                                                     scalingSettingsName:settings
                                                              oldElement:oldPlugin
                                                              newElement:[self delegateOwner]];
    
    
    [[self delegateOwner] setValue:newText forKey:@"richTextHTML"];
    
    return YES;
}

#pragma mark -
#pragma mark Data Source

+ (NSArray *)supportedPasteboardTypesForCreatingPagelet:(BOOL)isCreatingPagelet;
{
    return [NSArray arrayWithObjects:
            NSFilenamesPboardType,
            NSRTFDPboardType,
            NSRTFPboardType,
            NSStringPboardType,
            nil];
}

+ (unsigned)numberOfItemsFoundOnPasteboard:(NSPasteboard *)sender
{
    return 1;
}

+ (KTSourcePriority)priorityForItemOnPasteboard:(NSPasteboard *)pboard atIndex:(unsigned)dragIndex creatingPagelet:(BOOL)isCreatingPagelet;
{
    
	if (nil != [pboard availableTypeFromArray:[NSArray arrayWithObject:NSFilenamesPboardType]])
	{
		NSArray *fileNames = [pboard propertyListForType:NSFilenamesPboardType];
		if (dragIndex < [fileNames count])
		{
			NSString *fileName = [fileNames objectAtIndex:dragIndex];
			if ( nil != fileName )
			{
				// check to see if it's an rich text file
				NSString *aUTI = [NSString UTIForFileAtPath:fileName];	// takes account as much as possible
				if ([NSString UTI:aUTI conformsToUTI:(NSString *)kUTTypeRTF] || 
					[NSString UTI:aUTI conformsToUTI:(NSString *)kUTTypeFlatRTFD] ||
					[NSString UTI:aUTI conformsToUTI:(NSString *)kUTTypeRTFD] ||
					[NSString UTI:aUTI conformsToUTI:@"com.microsoft.word.doc"])
				{
					return KTSourcePriorityIdeal;
				}
				else if ([NSString UTI:aUTI conformsToUTI:(NSString *)kUTTypePlainText] ||
                         [aUTI conformsToUTI:(NSString *)kUTTypeFolder])
				{
					return KTSourcePriorityTypical;
				}
				/// MMMMmaybe we will handle other kind of text ... doubtful.
				else if ([NSString UTI:aUTI conformsToUTI:(NSString *)kUTTypeText])
				{
					return KTSourcePriorityFallback;
				}
				else
				{
					return KTSourcePriorityNone;		// doesn't look like a rich text file
				}
			}
		}
	}
    return KTSourcePriorityFallback;		// file-less rich text, this should be OK ... unless something better comes along
}

+ (BOOL)populateDataSourceDictionary:(NSMutableDictionary *)aDictionary
                      fromPasteboard:(NSPasteboard *)pasteboard
                             atIndex:(unsigned)dragIndex
				  forCreatingPagelet:(BOOL)isCreatingPagelet;

{
    BOOL result = NO;
    NSString *filePath= nil;
    
    NSArray *orderedTypes = [self supportedPasteboardTypesForCreatingPagelet:isCreatingPagelet];
    
    
    NSString *bestType = [pasteboard availableTypeFromArray:orderedTypes];
    if ( [bestType isEqualToString:NSFilenamesPboardType] )
    {
		NSArray *filePaths = [pasteboard propertyListForType:NSFilenamesPboardType];
		if (dragIndex < [filePaths count])
		{
			filePath = [filePaths objectAtIndex:dragIndex];
			if ( nil != filePath )
			{
				[aDictionary setValue:[[NSFileManager defaultManager] resolvedAliasPath:filePath]
							   forKey:kKTDataSourceFilePath];
				[aDictionary setValue:[filePath lastPathComponent] forKey:kKTDataSourceFileName];
				result = YES;
			}
		}
    }
	else
	{
		NSString *string = nil;
		// Get a title from the FIRST line of the text
		if (nil != [pasteboard availableTypeFromArray:[NSArray arrayWithObject:NSStringPboardType]]
            && nil != (string = [pasteboard stringForType:NSStringPboardType]))
		{
			NSString *firstLine = string;
			NSRange firstNewLine = [string rangeOfCharacterFromSet:[NSCharacterSet fullNewlineCharacterSet]];
			if (NSNotFound != firstNewLine.location)
			{
				firstLine = [string substringToIndex:firstNewLine.location];
			}
			[aDictionary setValue:firstLine forKey:kKTDataSourceTitle];
		}
		
		result = YES;	// client will get data from pasteboard
	}
    
    return result;
}

@end
