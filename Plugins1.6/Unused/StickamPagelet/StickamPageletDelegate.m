//
//  StickamPageletDelegate.m
//  StickamPagelet
//
//  Copyright 2006-2009 Karelia Software. All rights reserved.
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

#import "StickamPageletDelegate.h"
#import <KTComponents/KTComponents.h>


// LocalizedStringInThisBundle(@"Get Stickam for Free.", "String_On_Page_Template")
// LocalizedStringInThisBundle(@"Please enter your Stickam User ID using the Pagelet Inspector.", "String_On_Page_Template")
// LocalizedStringInThisBundle(@"Stickam (Placeholder)", "String_On_Page_Template")

@implementation StickamPageletDelegate

/*
 Plugin Properties we use:
 
stickamCode  
 
 
 ... to extract, look for roomID= or performerID=  or stickamPlayer/  followed by a number
 
 */

- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewObject
{
	[super awakeFromBundleAsNewlyCreatedObject:isNewObject];
	
	if ( isNewObject )
	{		
		NSURL *theURL = nil;
		NSString *theSource = nil;
		if ([NSAppleScript safariFrontmostURL:&theURL title:nil source:&theSource])
		{
			if (nil != theURL && nil != theSource && [[theURL host] isEqualToString:@"stickam.com"] || [[theURL host] isEqualToString:@"www.stickam.com"])
			{
				NSScanner *scanner = [NSScanner scannerWithString:theSource];
				BOOL found = [scanner scanUpToString:@"stickamPlayer/" intoString:nil];
				if (found && ![scanner isAtEnd])
				{
					[scanner scanString:@"stickamPlayer/" intoString:nil];
				}
				if (found)
				{
					NSString *theCode = nil;
					found = [scanner scanCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"01234567890-"] intoString:&theCode];
						
					if (found)
					{
						[[self pluginProperties] setObject:theCode forKey:@"stickamCode"];
					}
				}
			}
		}
	}
}




/*!	We define accessor methods here so that we can directly bind to the delegate from the nib,
-- the idea was to make use of the validator method -(BOOL)validateStickamCode:(id *)ioValue error:(NSError **)outError

	However, that's not working... so just do the validation/changing in the setter.
*/

- (NSString *)stickamCode
{
    return [[self pluginProperties] objectForKey:@"stickamCode"]; 
}

- (void)setStickamCode:(NSString *)aStickamCode
{
	// clean up the code so we have what we really want
	NSScanner *scanner = [NSScanner scannerWithString:aStickamCode];
	BOOL found = [scanner scanUpToString:@"stickamPlayer/" intoString:nil];
	if (found && ![scanner isAtEnd])
	{
		[scanner scanString:@"stickamPlayer/" intoString:nil];

		NSString *theCode = nil;
		found = [scanner scanCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"01234567890-"] intoString:&theCode];
		
		if (found)
		{
			aStickamCode = theCode;		// replace with what we scanned
			
			[self performSelector:@selector(setStickamCode:) withObject:theCode afterDelay:0.0];
		}
	}
	[[self pluginProperties] setObject:aStickamCode forKey:@"stickamCode"]; 
}

- (IBAction) openStickam:(id)sender
{
	[[NSWorkspace sharedWorkspace] attemptToOpenWebURL:[NSURL URLWithString:@"http://www.stickam.com/"]];
}

@end
