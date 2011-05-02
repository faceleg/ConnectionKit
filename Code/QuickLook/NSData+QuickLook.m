//
//  NSData+QuickLook.m
//  SandvoxQuickLook
//
//  Created by Mike on 19/02/2008.
//  Copyright 2008-2011 Karelia Software. All rights reserved.
//

#import "NSData+QuickLook.h"

#include <openssl/bio.h>
#include <openssl/evp.h>


@implementation NSData (QuickLook)

+ (NSData *)dataWithBase64EncodedString:(NSString *)base64String
{
	// Adapted from some Sample code modified by Scott Thompson <easco@mac.com>

	NSMutableData *retVal = nil;
	
	if([base64String canBeConvertedToEncoding:NSASCIIStringEncoding])
	{
		NSData *stringData = [base64String dataUsingEncoding: NSASCIIStringEncoding];
		
		// Create a memory buffer containing Base64 encoded string data
		BIO *memoryBuffer = BIO_new_mem_buf((void *) [stringData bytes], [stringData length]);
		
		// Push a Base64 filter so that reading from the buffer decodes the buffer as
		// Base64 info.
		BIO *base64Filter = BIO_new(BIO_f_base64());
		BIO_set_flags(base64Filter, BIO_FLAGS_BASE64_NO_NL);
		memoryBuffer = BIO_push(base64Filter, memoryBuffer);
		
		// Read the newly adorned buffer.  The data coming
		// out of it should be decoded Base64 information
		char readBuffer[512];
		int bytesRead;
		
		retVal = [NSMutableData data];
		while ((bytesRead = BIO_read(memoryBuffer, readBuffer, sizeof(readBuffer))) > 0)
		{
			[retVal appendBytes: readBuffer length: bytesRead];
		}
		
		// Clean up and go home
		BIO_free_all(memoryBuffer);
	}
	return retVal;
}

@end
