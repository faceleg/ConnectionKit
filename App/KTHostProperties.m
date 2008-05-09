//
//  KTStoredDictionary+HostProperties.m
//  Marvel
//
//  Created by Dan Wood on 5/25/05.
//  Copyright (c) 2005 Biophony LLC. All rights reserved.
//

#import "KTHostProperties.h"

#import "KTAppDelegate.h"
#import "KTHostSetupController.h"

#import "NSCharacterSet+Karelia.h"
#import "NSEntityDescription+KTExtensions.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSString+Karelia.h"
#import "NSString-Utilities.h"
#import "NSURL+Karelia.h"

#import "debug.h"


@implementation KTHostProperties

#pragma mark -
#pragma mark Init

- (void)awakeFromInsert
{
	[super awakeFromInsert];
	
	// For 1.5 certain properties are not user-accessible in the GUI. Instead, we load them from the defaults
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	[self setBool:[defaults boolForKey:@"deletePagesWhenPublishing"] forKey:@"deletePagesWhenPublishing"];
	[self setBool:[defaults boolForKey:@"PathsWithIndexPages"] forKey:@"PathsWithIndexPages"];
	[self setValue:[defaults objectForKey:@"htmlIndexBaseName"] forKey:@"htmlIndexBaseName"];
	[self setValue:[defaults objectForKey:@"archivesBaseName"] forKey:@"archivesBaseName"];
}

- (void)awakeFromFetch
{
	[super awakeFromFetch];
	
	// Make sure our properties are up-to-date with the defaults
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	BOOL deletePagesWhenPublishing = [defaults boolForKey:@"deletePagesWhenPublishing"];
	if (deletePagesWhenPublishing != [self boolForKey:@"deletePagesWhenPublishing"]) {
		[self setBool:deletePagesWhenPublishing forKey:@"deletePagesWhenPublishing"];
	}
	
	BOOL PathsWithIndexPages = [defaults boolForKey:@"PathsWithIndexPages"];
	if (PathsWithIndexPages != [self boolForKey:@"PathsWithIndexPages"]) {
		[self setBool:PathsWithIndexPages forKey:@"PathsWithIndexPages"];
	}
	
	NSString *htmlIndexBaseName = [defaults objectForKey:@"htmlIndexBaseName"];
	if (![htmlIndexBaseName isEqualToString:[self valueForKey:@"htmlIndexBaseName"]]) {
		[self setValue:htmlIndexBaseName forKey:@"htmlIndexBaseName"];
	}

	NSString *archivesBaseName = [defaults objectForKey:@"archivesBaseName"];
	if (![archivesBaseName isEqualToString:[self valueForKey:@"archivesBaseName"]]) {
		[self setValue:archivesBaseName forKey:@"archivesBaseName"];
	}
}

#pragma mark -
#pragma mark Host Info

- (NSString *)domainNameDashes
{
	NSMutableString *string = [NSMutableString stringWithString:[[self siteURL] absoluteString]];
	if ([string hasPrefix:@"http://"])
	{
		[string deleteCharactersInRange:NSMakeRange(0,7)];
	}
	if ([string hasSuffix:@"/"])
	{
		[string deleteCharactersInRange:NSMakeRange([string length]-1, 1)];
	}
	[string replace:@"." with:@"_"];
	[string replace:@"/" with:@"_"];
	unichar firstChar = [string characterAtIndex:0];
	if (   ![[NSCharacterSet characterSetWithRange:NSMakeRange((unsigned int)'A', 26)] characterIsMember:firstChar]
		&& ![[NSCharacterSet characterSetWithRange:NSMakeRange((unsigned int)'a', 26)] characterIsMember:firstChar])
	{
		[string insertString:@"host_" atIndex:0];
	}
	return [string stringByRemovingCharactersInSet:[[NSCharacterSet alphanumericASCIIUnderlineCharacterSet] invertedSet]];
}

- (NSString *)localPublishingRoot
{
	NSString *result = @"/";
	
	if (0 == [[self valueForKey:@"localSharedMatrix"] intValue])
	{
		result = [NSString stringWithFormat:@"/~%@", NSUserName()];
	}
	NSString *localSubFolder = [self valueForKey:@"localSubFolder"];
	if (nil != localSubFolder && ![localSubFolder isEqualToString:@""])
	{
		result = [result stringByAppendingPathComponent:localSubFolder];
	}

	if (![result hasSuffix:@"/"])		// make sure it ends with /
	{
		result = [result stringByAppendingString:@"/"];
	}
	
	return result;
}

// Root, starting with slash

- (NSString *)remotePublishingRoot
{
	NSString *result = nil;
	
	NSString *stemURLString = [self valueForKey:@"stemURL"];
	if (nil == stemURLString)
	{
		stemURLString = @"http://unpublished.example.com";		// placeholder
	}
	NSMutableString *stem = [NSMutableString stringWithString:stemURLString];
	NSString *userID = [self valueForKey:@"userName"];
	if (nil != userID)
	{
		[stem replaceOccurrencesOfString:@"?" withString:userID options:0 range:NSMakeRange(0, [stem length])];
	}
	// Now get just the path part
	NSURL *stemURL = [NSURL URLWithString:[stem encodeLegally]];
	result = [stemURL path];	// won't end in slash
	
	NSString *subFolder = [self valueForKey:@"subFolder"];
	if (nil != subFolder && ![subFolder isEqualToString:@""])
	{
		result = [result stringByAppendingPathComponent:subFolder];
	}
	if (![result hasSuffix:@"/"])		// make sure it ends with /
	{
		result = [result stringByAppendingString:@"/"];
	}
	return result;

}


- (NSString *)localURL
{
	BOOL homeDirectory = (HOMEDIR == [[self valueForKey:@"localSharedMatrix"] intValue]);
	NSMutableString *result = [NSMutableString string];
	[result appendFormat:@"http://%@/", [[NSProcessInfo processInfo] hostName]];
	if (homeDirectory)
	{
		[result appendFormat:@"~%@/", NSUserName()];
	}
	NSString *subFolder = [self valueForKey:@"localSubFolder"];
	if (nil != subFolder && ![subFolder isEqualToString:@""])
	{
		[result appendString:[subFolder urlEncode]];
		if (![result hasSuffix:@"/"])		// make sure it ends with /
		{
			[result appendString:@"/"];
		}
	}
	return result;
}


/*!	Support method -- determine local host name, or addres.   May return nil if we couldn't get an address.
*/
- (NSString *)localHostNameOrAddress
{
	NSString * hostName = [self valueForKey:@"localHostName"];
/*
 No longer doing -- no home base dict.
	if (nil == hostName || [hostName isEqualToString:@""])
	{
		hostName = [[[NSApp delegate] homeBaseDict] valueForKey:@"REMOTE_ADDR"];
	}
*/
	return hostName;
}

/*!	Support method.  Calculate URL up to the home directory (if specified), as seen from the outside world
*/
- (NSString *)globalBaseURLUsingHome:(BOOL)inHome
{
	NSMutableString *result = nil;
	NSString *hostName = [self localHostNameOrAddress];
	if (nil != hostName)
	{
		result = [NSMutableString stringWithFormat:@"http://%@/", hostName];
		if (inHome)
		{
			[result appendFormat:@"~%@/", NSUserName()];
		}
	}
	return result;
}

/*!	Calculate URL as seen from the outside world
*/
- (NSString *)globalSiteURL
{
	NSMutableString *result = nil;
	BOOL homeDirectory = (HOMEDIR == [[self valueForKey:@"localSharedMatrix"] intValue]);
	NSString *baseURL = [self globalBaseURLUsingHome:homeDirectory];
	if (nil != baseURL)
	{
		result = [NSMutableString stringWithString:baseURL];
		NSString *subFolder = [self valueForKey:@"localSubFolder"];
		if (nil != subFolder && ![subFolder isEqualToString:@""])
		{
			[result appendString:[subFolder urlEncode]];
			if (![result hasSuffix:@"/"])		// make sure it ends with /
			{
				[result appendString:@"/"];
			}
		}
	}
	return result;
}



- (BOOL)remoteSiteURLIsValid
{
	NSString *stem = [self valueForKey:@"stemURL"];
	BOOL valid = (nil != stem);
	if (valid)
	{
		NSRange foundQMark = [stem rangeOfString:@"?"];
		if (NSNotFound != foundQMark.location)
		{
			valid = (nil != [self valueForKey:@"userName"]);	// must have user name if ? found!
		}
	}
	return valid;
}

/*!	Construct remote URL.  If data is missing, it will construct placeholder.
*/
- (NSString *)remoteSiteURL
{
	NSMutableString *result = nil;
	NSString *stem = [self valueForKey:@"stemURL"];
	NSString *userName = [self valueForKey:@"userName"];
	if (nil != stem)
	{
		// replace ? with user name
		result = [NSMutableString stringWithString:stem];
		if (nil != userName)
		{
			[result replaceOccurrencesOfString:@"?" withString:userName options:0 range:NSMakeRange(0, [result length])];
		}
	}
	
	// Now append in the subFolder.  Dan adding this back in -- Greg had taken it out in r1597 with
	// the comment "Fixes the problem when specifying the sub folder would get the published url out of sync"
	// 
	// The problem with that was that it basically screwed up everybody using subfolder, EVERYWHERE!
	//
	// So whatever the fix that was needed, this was not the solution.
	//
	// I'm also fixing this a bit so that it doesn't end with two slashes
	//
	if (nil != result)
	{
		NSString *subFolder = [self valueForKey:@"subFolder"];
		if (nil != subFolder && ![subFolder isEqualToString:@""])
		{
			[result appendString:subFolder];
			if (![result hasSuffix:@"/"])		// make sure it ends with /
			{
				[result appendString:@"/"];
			}
		}
	}
	
	return result;
}

/*!	URL representation of the host.  We don't actually use this except for display of what the URL would look like,
but it also serves as a signature of the upload configuration so we will know if it has changed, and if it needs
to be verified.
*/

- (NSString *)uploadURL
{
	NSMutableString *result = [NSMutableString string];
	NSString *userName = [self valueForKey:@"userName"];
	NSString *docRoot = [self valueForKey:@"docRoot"];
	NSString *protocol = [[self valueForKey:@"protocol"] lowercaseString];
	if ([protocol isEqualToString:@"webdav"] || [protocol isEqualToString:@".mac"])
	{
		protocol = @"http";
	}
	
	if (protocol != nil)
	{
		[result appendString:protocol];
		[result appendString:@"://"];
		if (nil != userName)
		{
			[result appendString:userName];
			[result appendString:@":****@"];	// asterisks don't look as cool as bullets but they look better in the  console log than \U2022
		}
		if (nil != [self valueForKey:@"hostName"])
		{
			[result appendString:[self valueForKey:@"hostName"]];
			
			if (nil != [self valueForKey:@"port"])
			{
				[result appendString:@":"];
				[result appendString:[[self valueForKey:@"port"] description]];
			}
			if (nil == docRoot)
			{
				[result appendString:@"/"];		// no docroot, just append a slash
			}
			else
			{
				if (![docRoot hasPrefix:@"/"])
				{
					// doesn't start with / so it's not an absolute path.  So we don't really have a real upload URL.  Put in some
					// ellipses so we can still see what we're working with.
					[result appendString:@" - "];
				}
				// replace ? with user name
				NSMutableString *mutableDocRoot = [NSMutableString stringWithString:docRoot];
				if (nil != userName)
				{
					[mutableDocRoot replaceOccurrencesOfString:@"?" withString:userName options:0 range:NSMakeRange(0, [docRoot length])];
				}
				[result appendString:mutableDocRoot];	// includes trailing /
			}
			
			NSString *subFolder = [self valueForKey:@"subFolder"];
			if (nil != subFolder  && ![subFolder isEqualToString:@""])
			{
				[result appendString:subFolder];
				if (![result hasSuffix:@"/"])		// make sure it ends with /
				{
					[result appendString:@"/"];
				}
			}
		}
	}
	return result;
}

- (void)setStemURL:(NSString *)someString
{
	[self setWrappedValue:someString forKey:@"stemURL"];
}

/*!	Returns the base of the url like http://mysite.mydomain.com/~user/thisSite/ 
 */
- (NSURL *)siteURL
{
	NSString *result = nil;
	
	NSNumber *useLocalHosting = [self valueForKey:@"localHosting"];
	if (useLocalHosting)
	{
		if ([useLocalHosting boolValue])
		{
			result = [self globalSiteURL];
		}
		else
		{
			result = [self remoteSiteURL];
		}
	}
	
	// Bckup option
	if (!result)
	{
		result = @"http://unpublished.example.com/";
	}
		
	OBPOSTCONDITION(result);	
	return [NSURL URLWithString:result];
}

#pragma mark -
#pragma mark Resources

- (NSURL *)resourcesDirectoryURL
{
	NSString *resourcesDirectoryName = [[NSUserDefaults standardUserDefaults] valueForKey:@"DefaultResourcesPath"];
	NSURL *result = [NSURL URLWithPath:resourcesDirectoryName relativeToURL:[self siteURL] isDirectory:YES];
	
	OBPOSTCONDITION(result);
	return result;
}

- (NSURL *)URLForResourceFile:(NSString *)filename
{
	OBPRECONDITION(filename);
	
	NSURL *result = [NSURL URLWithPath:[filename lastPathComponent] 
						 relativeToURL:[self resourcesDirectoryURL]
						   isDirectory:NO];
	
	OBPOSTCONDITION(result);
	return result;
}

#pragma mark -
#pragma mark Troubleshooting

- (NSString *)hostPropertiesReport
{
	NSMutableDictionary *propertyDescriptions = [NSMutableDictionary dictionaryWithDictionary:
		[[self entity] propertiesByNameOfClass:[NSAttributeDescription class] includeTransientProperties:NO]];
	[propertyDescriptions removeObjectForKey:[[self class] extensiblePropertiesDataKey]];
	
	
	NSMutableDictionary *buffer = [[self dictionaryWithValuesForKeys:[propertyDescriptions allKeys]] mutableCopy];
	OBASSERT(buffer);
	[buffer addEntriesFromDictionary:[self extensibleProperties]];
	[buffer removeObjectsForKeys:[buffer allKeysForObject:[NSNull null]]];	// Ignore NULL properties
	
	
	// Finish up
	NSString *result = [buffer description];
	[buffer release];
	return result;
}

@end

