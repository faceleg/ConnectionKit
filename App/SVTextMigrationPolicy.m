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

- (BOOL)createDestinationMediaGraphicsForSourceInstance:(NSManagedObject *)sInstance entityMapping:(NSEntityMapping *)mapping manager:(SVMigrationManager *)manager error:(NSError **)error;
{
    Class class = NSClassFromString([mapping entityMigrationPolicyClassName]);
    if (!class) class = [NSEntityMigrationPolicy class];
    NSEntityMigrationPolicy *graphicPolicy = [[class alloc] init];
    
    BOOL result = [graphicPolicy createDestinationInstancesForSourceInstance:sInstance
                                                                  entityMapping:mapping
                                                                        manager:manager
                                                                          error:error];
    
    [graphicPolicy release];
    return result;
}

- (BOOL)createDestinationTextAttachmentsForSourceInstance:(NSManagedObject *)sInstance entityMapping:(NSEntityMapping *)mapping manager:(SVMigrationManager *)manager error:(NSError **)error;
{
    Class class = NSClassFromString([mapping entityMigrationPolicyClassName]);
    if (!class) class = [NSEntityMigrationPolicy class];
    NSEntityMigrationPolicy *attachmentPolicy = [[class alloc] init];
    
    BOOL result = [attachmentPolicy createDestinationInstancesForSourceInstance:sInstance
                                                                  entityMapping:mapping
                                                                        manager:manager
                                                                          error:error];
    
    [attachmentPolicy release];
    return result;
}

- (BOOL)createDestinationInstancesForSourceInstance:(NSManagedObject *)sInstance entityMapping:(NSEntityMapping *)mapping manager:(SVMigrationManager *)manager error:(NSError **)error;
{
    if (![self shouldCreateDestinationInstancesForSourceInstance:sInstance entityMapping:mapping]) return YES;
    
    
    // Locate HTML
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
        if (!string)    // rich text plus
        {
            string = [[properties objectForKey:@"richTextHTML1"] stringByAppendingString:
                      [[properties objectForKey:@"richTextHTML2"] stringByAppendingString:
                       [properties objectForKey:@"richTextHTML3"]]];

        }
        
        
        // Page intro too?
        if ([[mapping name] isEqualToString:@"PageToArticle"])
        {
            NSString *intro = [sInstance valueForKey:@"introductionHTML"];
            if ([intro length])
            {
                string = (string ? [intro stringByAppendingString:string] : intro);
            }
        }
    }
    
    
    // Insert new
    NSManagedObject *article = [NSEntityDescription insertNewObjectForEntityForName:[mapping destinationEntityName]
                                                             inManagedObjectContext:[manager destinationContext]];
    
        
    if ([string length])
    {
        
        
        
        
        
        
        
        
        
        /*
        
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
            if (![self createDestinationMediaGraphicsForSourceInstance:sInstance
                                                         entityMapping:graphicMapping
                                                               manager:manager
                                                                 error:error]) return NO;
            
            // Title
            NSEntityMapping *graphicTextMapping = [[[manager mappingModel] entityMappingsByName] objectForKey:@"EmbeddedImageToPageletTitle"];
            if (![self createDestinationMediaGraphicsForSourceInstance:sInstance
                                                         entityMapping:graphicTextMapping
                                                               manager:manager
                                                                 error:error]) return NO;
            
            
            
            // Intro
            graphicTextMapping = [[[manager mappingModel] entityMappingsByName] objectForKey:@"EmbeddedImageToPageletIntroduction"];
            if (![self createDestinationMediaGraphicsForSourceInstance:sInstance
                                                         entityMapping:graphicTextMapping
                                                               manager:manager
                                                                 error:error]) return NO;
            
            
            
            // Caption
            graphicTextMapping = [[[manager mappingModel] entityMappingsByName] objectForKey:@"EmbeddedImageToPageletCaption"];
            if (![self createDestinationMediaGraphicsForSourceInstance:sInstance
                                                         entityMapping:graphicTextMapping
                                                               manager:manager
                                                                 error:error]) return NO;
            
            
            
            // Text attachment
            NSEntityMapping *attachmentMapping = [[[manager mappingModel] entityMappingsByName] objectForKey:@"EmbeddedImageToTextAttachment"];
            if (![self createDestinationTextAttachmentsForSourceInstance:sInstance
                                                           entityMapping:attachmentMapping
                                                                 manager:manager
                                                                   error:error]) return NO;
        }
        
        
        // Going to cheat a little and connect attachments, graphics, media up now
        NSArray *attachments = [manager destinationInstancesForEntityMappingNamed:@"EmbeddedImageToTextAttachment"
                                                                  sourceInstances:[NSArray arrayWithObject:sInstance]];
        
        NSArray *graphics = [manager destinationInstancesForEntityMappingNamed:@"EmbeddedImageToMediaGraphic"
                                                               sourceInstances:[NSArray arrayWithObject:sInstance]];
        
        NSArray *media = [manager destinationInstancesForEntityMappingNamed:@"EmbeddedImageToGraphicMedia"
                                                            sourceInstances:[NSArray arrayWithObject:sInstance]];
        
        NSArray *titles = [manager destinationInstancesForEntityMappingNamed:@"EmbeddedImageToPageletTitle"
                                                             sourceInstances:[NSArray arrayWithObject:sInstance]];
        
        NSArray *introductions = [manager destinationInstancesForEntityMappingNamed:@"EmbeddedImageToPageletIntroduction"
                                                                    sourceInstances:[NSArray arrayWithObject:sInstance]];
        
        NSArray *captions = [manager destinationInstancesForEntityMappingNamed:@"EmbeddedImageToPageletCaption"
                                                               sourceInstances:[NSArray arrayWithObject:sInstance]];
        
        
        
        NSUInteger count = [graphics count];
        OBASSERT(count == [attachments count]);
        OBASSERT(count == [media count]);
        OBASSERT(count == [titles count]);
        OBASSERT(count == [introductions count]);
        OBASSERT(count == [captions count]);
        
        
        NSUInteger i;
        for (i = 0; i < count; i++)
        {
            NSManagedObject *anAttachment = [attachments objectAtIndex:i];
            NSManagedObject *aGraphic = [graphics objectAtIndex:i];
            NSManagedObject *aTitle = [titles objectAtIndex:i];
            NSManagedObject *anIntro = [introductions objectAtIndex:i];
            NSManagedObject *aCaption = [captions objectAtIndex:i];
            NSManagedObject *aMedia = [media objectAtIndex:i];
            
            NSDictionary *props = [KSExtensibleManagedObject unarchiveExtensibleProperties:[aMedia valueForKey:@"extensiblePropertiesData"]];
            [aGraphic setValue:[props objectForKey:@"mediaContainerIdentifier"] forKey:@"identifier"];
            
            [anAttachment setValue:aGraphic forKey:@"graphic"];
            [aGraphic setValue:aTitle forKey:@"titleBox"];
            [aGraphic setValue:anIntro forKey:@"introduction"];
            [aGraphic setValue:aCaption forKey:@"caption"];
            [aGraphic setValue:aMedia forKey:@"media"];
        }*/
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
        
        BOOL isCallout = [[manager sourceInstancesForEntityMappingNamed:@"CalloutToTextAttachment"
                                                   destinationInstances:[NSArray arrayWithObject:anAttachment]] count];
        
        
        //else if ([[anAttachment valueForKey:@"location"] shortValue] >= 32767) break;    // we've reached the embedded images
        
        if (isCallout)
        {
            // Correct location in case source document was a little wonky
            
            NSString *string = [[NSString stringWithUnichar:NSAttachmentCharacter] stringByAppendingString:[dInstance valueForKey:@"string"]];
            [dInstance setValue:string forKey:@"string"];
            
            [anAttachment setValue:[NSNumber numberWithUnsignedInteger:i] forKey:@"location"];
        }
        else
        {
            NSString *string = [[dInstance valueForKey:@"string"] stringByAppendingString:[NSString stringWithUnichar:NSAttachmentCharacter]];
            [dInstance setValue:string forKey:@"string"];
            
            [anAttachment setValue:[NSNumber numberWithUnsignedInteger:([string length] - 1)] forKey:@"location"];
        }
    }
    
    
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

- (NSString *)placeholderTitleForSourceInstance:(NSManagedObject *)sInstance; { return @"Untitled"; }

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
        html = [KSXMLWriter stringFromCharacters:[factory name]];
        
        if (!html) html = [self placeholderTitleForSourceInstance:sInstance];
    }
    
    [dInstance setValue:NSBOOL(hidden) forKey:@"hidden"];
    [dInstance setValue:html forKey:@"textHTMLString"];
    
    [manager associateSourceInstance:sInstance withDestinationInstance:dInstance forEntityMapping:mapping];
    
    return YES;
}

@end


@implementation SVPageTitleMigrationPolicy

- (NSString *)placeholderTitleForSourceInstance:(NSManagedObject *)sInstance;
{
    // #109088
    NSString *result = [sInstance valueForKey:@"menuTitle"];
    if (![result length])
    {
        if (![sInstance valueForKey:@"parent"])
        {
            result = [sInstance valueForKeyPath:@"master.siteTitleHTML"];
        }
        
        if (![result length])
        {
            result = [super placeholderTitleForSourceInstance:sInstance];
        }
    }
    
    return result;
}

@end


@implementation SVFooterMigrationPolicy

- (NSString *)stringFromHTMLString:(NSString *)string;
{
    // Make sure it's non-nil is all that's needed
    if (!string) string = @"";
    return string;
}

@end

