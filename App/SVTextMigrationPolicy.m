//
//  SVTextMigrationPolicy.m
//  Sandvox
//
//  Created by Mike on 15/02/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVTextMigrationPolicy.h"

#import "SVMediaMigrationPolicy.h"
#import "SVMigrationManager.h"

#import "SVArticle.h"
#import "KSExtensibleManagedObject.h"
#import "SVGraphicFactory.h"

#import "NSSet+Karelia.h"
#import "NSString+Karelia.h"

#import "KSStringHTMLEntityUnescaping.h"
#import "KSStringXMLEntityEscaping.h"


@implementation SVArticleMigrationPolicy

- (void)associateSourceInstance:(NSManagedObject *)sInstance withDestinationInstance:(NSManagedObject *)dInstance forEntityMapping:(NSEntityMapping *)mapping manager:(NSMigrationManager *)manager;
{
    [manager associateSourceInstance:sInstance withDestinationInstance:dInstance forEntityMapping:mapping];
}

+ (NSString *)mediaContainerIdentifierForURI:(NSURL *)mediaURI
{
    NSString *result = nil;
    
    if ([[mediaURI scheme] isEqualToString:@"svxmedia"])
	{
        NSArray *pathComponents = [[mediaURI path] pathComponents];
        if ([pathComponents count] == 2)
        {
            result = [pathComponents objectAtIndex:1];
        }
    }
    
    return result;
}

+ (NSSet *)mediaContainerIdentifiersInHTML:(NSString *)HTML
{
    NSMutableSet *buffer = [[NSMutableSet alloc] init];
    if (HTML)
	{
		NSScanner *imageScanner = [[NSScanner alloc] initWithString:HTML];
		while (![imageScanner isAtEnd])
		{
			// Look for an image tag
			[imageScanner scanUpToString:@"<img" intoString:NULL];
			if ([imageScanner isAtEnd]) break;
			
			
			// Locate the image's source attribute
			[imageScanner scanUpToString:@"src=\"" intoString:NULL];
			[imageScanner scanString:@"src=\"" intoString:NULL];
			
			NSString *aMediaURIString = nil;
			if ([imageScanner scanUpToString:@"\"" intoString:&aMediaURIString])
			{
				NSURL *aMediaURI = [[NSURL alloc] initWithString:aMediaURIString];
				[buffer addObjectIgnoringNil:[self mediaContainerIdentifierForURI:aMediaURI]];
				[aMediaURI release];
			}
		}    
		
		[imageScanner release];
	}
    
    NSSet *result = [[buffer copy] autorelease];
    [buffer release];
    return result;
}

- (NSString *)processHTML:(NSString *)result
{/*
    WebView *webview = [[WebView alloc] init];
    [webview setResourceLoadDelegate:self];
    [[webview mainFrame] loadHTMLString:result baseURL:nil];
    
    while ([webview isLoading])
    {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate distantPast]];
    }*/
    
    
    
    /*
			// Convert media source paths
			NSScanner *scanner = [[NSScanner alloc] initWithString:result];
			NSMutableString *buffer = [[NSMutableString alloc] initWithCapacity:[result length]];
			NSString *aString;	NSString *aMediaPath;
			
			while (![scanner isAtEnd])
			{
				[scanner scanUpToString:@" src=\"" intoString:&aString];
				OBASSERT(aString);
				[buffer appendString:aString];
				if ([scanner isAtEnd]) break;
				
				[buffer appendString:@" src=\""];
				[scanner setScanLocation:([scanner scanLocation] + 6)];
				
				if ([scanner scanUpToString:@"\"" intoString:&aMediaPath])
				{
					NSURL *aMediaURI = [NSURL URLWithString:aMediaPath];
					
					// Replace the path with one suitable for the specified purpose
					KTMediaContainer *mediaContainer = [KTMediaContainer mediaContainerForURI:aMediaURI];
					if (mediaContainer)
					{
						if ([[self parser] HTMLGenerationPurpose] == kGeneratingQuickLookPreview)
						{
							aMediaPath = [[mediaContainer file] quickLookPseudoTag];
						}
						else
						{
							KTAbstractPage *page = [[self parser] currentPage];
							KTMediaFile *mediaFile = [mediaContainer sourceMediaFile];
                            KTMediaFileUpload *upload = [mediaFile uploadForScalingProperties:[(KTScaledImageContainer *)mediaContainer latestProperties]];
							aMediaPath = [[upload URL] stringRelativeToURL:[page URL]];
							
							// Tell the parser's delegate
							[[self parser] didEncounterMediaFile:mediaFile upload:upload];
						}
					}
					
					
					// Add the processed path back in. For external images, it should remain unchanged
					if (aMediaPath) [buffer appendString:aMediaPath];
				}
			}
			
			
			// Finish up
			result = [NSString stringWithString:buffer];
			[buffer release];
			[scanner release];
    
    
    */
    return result;
}

- (NSURLRequest *)webView:(WebView *)sender resource:(id)identifier willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse fromDataSource:(WebDataSource *)dataSource
{
    
    
    return request;
}

- (BOOL)createDestinationInstancesForSourceInstance:(NSManagedObject *)sInstance entityMapping:(NSEntityMapping *)mapping manager:(SVMigrationManager *)manager error:(NSError **)error;
{
    // Loate HTML
    NSString *keyPath = [[mapping userInfo] objectForKey:@"stringKeyPath"];
    NSString *string;
    
    if ([[[sInstance entity] attributesByName] objectForKey:keyPath])
    {
        string = [sInstance valueForKey:keyPath];
    }
    else
    {
        NSDictionary *properties = [KSExtensibleManagedObject unarchiveExtensibleProperties:[sInstance valueForKey:@"extensiblePropertiesData"]];
        string = [properties valueForKeyPath:keyPath];
    }
    
    
    // Insert new
    NSManagedObject *article = [NSEntityDescription insertNewObjectForEntityForName:[mapping destinationEntityName]
                                                             inManagedObjectContext:[manager destinationContext]];
    
        
    if ([string length])
    {
        // Import embedded images
        NSSet *IDs = [[self class] mediaContainerIdentifiersInHTML:string];
        for (NSString *anID in IDs)
        {
            // Media
            NSEntityMapping *mediaMapping = [[[manager mappingModel] entityMappingsByName] objectForKey:@"EmbeddedImageToGraphicMedia"];
            SVMediaMigrationPolicy *policy = [[NSClassFromString([mediaMapping entityMigrationPolicyClassName]) alloc] init];
            
            NSManagedObject *media = [policy createDestinationInstanceForSourceInstance:sInstance
                                                               mediaContainerIdentifier:anID
                                                                          entityMapping:mediaMapping
                                                                                manager:manager
                                                                                  error:error];
            [policy release];
            if (!media) return NO;
            
            
            // Graphic
            NSEntityMapping *graphicMapping = [[[manager mappingModel] entityMappingsByName] objectForKey:@"EmbeddedImageToMediaGraphic"];
            Class class = NSClassFromString([graphicMapping entityMigrationPolicyClassName]);
            if (!class) class = [NSEntityMigrationPolicy class];
            NSEntityMigrationPolicy *graphicPolicy = [[class alloc] init];
            
            if (![graphicPolicy createDestinationInstancesForSourceInstance:sInstance
                                                              entityMapping:graphicMapping
                                                                    manager:manager
                                                                      error:error])
            {
                return NO;
            }
            [graphicPolicy release];
            
            
            // Text attachment
            NSEntityMapping *attachmentMapping = [[[manager mappingModel] entityMappingsByName] objectForKey:@"EmbeddedImageToTextAttachment"];
            class = NSClassFromString([attachmentMapping entityMigrationPolicyClassName]);
            if (!class) class = [NSEntityMigrationPolicy class];
            NSEntityMigrationPolicy *attachmentPolicy = [[class alloc] init];
            
            if (![attachmentPolicy createDestinationInstancesForSourceInstance:sInstance
                                                              entityMapping:attachmentMapping
                                                                    manager:manager
                                                                      error:error])
            {
                return NO;
            }
            [attachmentPolicy release];
            
        }
    }
    else
    {
        if ([keyPath isEqualToString:@"richTextHTML"])
        {
            string = @"";
        }
        else
        {
            string = @"<p><br /></p>";
        }
    }
    [article setValue:string forKey:@"string"];
    
    
    [self associateSourceInstance:sInstance withDestinationInstance:article forEntityMapping:mapping manager:manager];
     
    return YES;
}

- (BOOL)createRelationshipsForDestinationInstance:(NSManagedObject *)dInstance entityMapping:(NSEntityMapping *)mapping manager:(NSMigrationManager *)manager error:(NSError **)error;
{
    if (![super createRelationshipsForDestinationInstance:dInstance entityMapping:mapping manager:manager error:error]) return NO;
    
    
    // Fully hook up attachments
    NSArray *attachments = [[dInstance valueForKey:@"attachments"] KS_sortedArrayUsingDescriptors:[SVRichText attachmentSortDescriptors]];
    NSUInteger i, count = [attachments count];
    
    for (i = 0; i < count; i++)
    {
        NSManagedObject *anAttachment = [attachments objectAtIndex:i];
        if ([[anAttachment valueForKey:@"location"] shortValue] >= 32767) break;    // we've reached the embedded images
        
        // Correct location in case source document was a little wonky
        
        NSString *string = [[NSString stringWithUnichar:NSAttachmentCharacter] stringByAppendingString:[dInstance valueForKey:@"string"]];
        [dInstance setValue:string forKey:@"string"];
        
        [anAttachment setValue:[NSNumber numberWithUnsignedInteger:i] forKey:@"location"];
    }
    
    
    // TODO: Create a graphic for each embedded image
    
    
    return YES;
}

@end



@implementation SVAuxiliaryPageletTextMigrationPolicy

- (void)associateSourceInstance:(NSManagedObject *)sInstance withDestinationInstance:(NSManagedObject *)dInstance forEntityMapping:(NSEntityMapping *)mapping manager:(NSMigrationManager *)manager;
{
    // Also import whether to hide
    BOOL hide = [[dInstance valueForKeyPath:@"string.stringByConvertingHTMLToPlainText"] length] == 0;
    [dInstance setValue:NSBOOL(hide) forKey:@"hidden"];
    
    [super associateSourceInstance:sInstance withDestinationInstance:dInstance forEntityMapping:mapping manager:manager];
}

@end


@implementation SVTitleMigrationPolicy

- (BOOL)createDestinationInstancesForSourceInstance:(NSManagedObject *)sInstance entityMapping:(NSEntityMapping *)mapping manager:(NSMigrationManager *)manager error:(NSError **)error;
{
    NSManagedObject *dInstance = [NSEntityDescription insertNewObjectForEntityForName:[mapping destinationEntityName]
                                                               inManagedObjectContext:[manager destinationContext]];
    
    NSString *html = [sInstance valueForKey:@"titleHTML"];
    BOOL hidden = NO;
    
    if (![[html stringByConvertingHTMLToPlainText] length])
    {
        // There was no visible text, so user deleted it in 1.x. Reset to a default title, and make hidden
        hidden = YES;
        
        NSString *identifier = [sInstance valueForKey:@"pluginIdentifier"];
        SVGraphicFactory *factory = [SVGraphicFactory factoryWithIdentifier:identifier];
        html = [[factory name] stringByEscapingHTMLEntities];
        
        if (!html) html = @"Untitled";
    }
    
    [dInstance setValue:NSBOOL(hidden) forKey:@"hidden"];
    [dInstance setValue:html forKey:@"textHTMLString"];
    
    [manager associateSourceInstance:sInstance withDestinationInstance:dInstance forEntityMapping:mapping];
    
    return YES;
}

@end
