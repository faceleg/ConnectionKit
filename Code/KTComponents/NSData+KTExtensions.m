//
//  NSData+KTExtensions.m
//  KTComponents
//
//  Copyright (c) 2004-2005 Biophony LLC. All rights reserved.
//

#import "NSData+Karelia.h"

#import "Debug.h"
#import "bzlib.h"
#import <zlib.h>
#include <openssl/bio.h>
#include <openssl/evp.h>

@implementation NSData ( KTExtensions )





/*
	for a definitive list of magic number check out:
 http://www.garykessler.net/library/file_sigs.html
 http://en.wikipedia.org/wiki/Magic_number_(programming)
 
 Also:  man 5 magic  .... /usr/share/file/magic
 */

- (BOOL)containsFaviconImageData
{
	// first 8 bytes is 0x00000100
    
    // do we have data of at least 4 bytes?
    if ( [self length] >= 4 )
    {
        unsigned char header[8] = {0x00, 0x00, 0x01, 0x00};
        if (memcmp([self bytes],header,4) == 0)
        {
            return YES;
        }
    }
	
	return NO;
}

- (BOOL)containsTIFFImageData
{
	// intel = 0x49492A00
	// motorola = 0x4D4D002A
    
    // do we have data of at least 4 bytes?
    if ( [self length] >= 4 )
    {
        unsigned char intel[4] = {0x49, 0x49, 0x2A, 0x00};
        unsigned char motorola[4] = {0x4D, 0x4D, 0x00, 0x2A};
        if (memcmp([self bytes],intel,4) == 0 ||
            memcmp([self bytes],motorola,4) == 0)
        {
            return YES;
        }
    }
    
	return NO;
}

- (BOOL)containsJPEGImageData
{
	// first 11 bytes is 0xffd8ffe101064578696600 for EXIF
	// first 11 bytes is 0xffd8ffe000104a46494600 for JFIF

    // do we have data of at least 11 bytes?
    if ( [self length] >= 11 )
    {
        unsigned char exif[5] = {0x45, 0x78, 0x69, 0x66, 0x00};
        unsigned char jfif[5] = {0x4a, 0x46, 0x49, 0x46, 0x00};
        if (memcmp([self bytes]+6,exif,5) == 0 ||
            memcmp([self bytes]+6,jfif,5) == 0)
        {
            return YES;
        }
    }
	
	return NO;
}

- (BOOL)containsPNGImageData
{
	// first 8 bytes is 0x89504e470d0a1a0a
    
    // do we have data of at least 8 bytes?
    if ( [self length] >= 8 )
    {
        unsigned char header[8] = {0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a};
        if (memcmp([self bytes],header,8) == 0)
        {
            return YES;
        }
    }
	
	return NO;
}

- (BOOL)containsGIFImageData
{
	// gif89a = 0x474946383961 gif87a = 0x474946383761
    
    // do we have data of at least 6 bytes?
    if ( [self length] >= 6 )
    {
        unsigned char header1[6] = {0x47, 0x49, 0x46, 0x38, 0x39, 0x61};
        unsigned char header2[6] = {0x47, 0x49, 0x46, 0x38, 0x37, 0x61};
        if (memcmp([self bytes],header1,6) == 0 ||
            memcmp([self bytes],header2,6) == 0)
        {
            return YES;
        }
    }
    
	return NO;
}



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

- (NSString *)base64Encoding
{
	// Adapted from some Sample code modified by Scott Thompson <easco@mac.com>
	
	// Create a memory buffer which will contain the Base64 encoded data
    BIO *memoryBuffer = BIO_new(BIO_s_mem());
	
    // Push on a Base64 filter onto the buffer so that writing to the buffer
	// encodes the data
    BIO *base64Filter = BIO_new(BIO_f_base64());
	BIO_set_flags(base64Filter, BIO_FLAGS_BASE64_NO_NL);
    memoryBuffer = BIO_push(base64Filter, memoryBuffer);
	
    // Encode all the data
    BIO_write(memoryBuffer, [self bytes], [self length]);
    BIO_flush(memoryBuffer);
	
    // Create new dataa with the contents of that memory buffer
    char *base64Pointer = NULL;
    long base64Length = BIO_get_mem_data(memoryBuffer, &base64Pointer);
	
    NSString* base64Encoded = [[NSString alloc] initWithBytes: base64Pointer length: base64Length encoding: NSASCIIStringEncoding];
	
    // Clean up
    BIO_free_all(memoryBuffer);
    return base64Encoded;
}

+ (NSData *)dataFromXMLPropertyList:(NSString *)aPropertyList
{
    NSString *errorString;
    NSData *theData = [NSPropertyListSerialization dataFromPropertyList:aPropertyList
                                                                 format:NSPropertyListXMLFormat_v1_0
                                                       errorDescription:&errorString];
    if ( nil == theData )
    {
        LOG((@"NSData +dataWithXMLPropertyList: error:%@", errorString));
        [errorString release];
        return nil;
    }
    
    return theData;
}

/*! serializes as NSData, NSData, NSString, NSNumber, NSDate, NSArray, or NSDictionary in XML format */
+ (NSData *)dataFromFoundationObject:(id)aFoundationObject
{
    NSString *errorString;
    NSData *theData = [NSPropertyListSerialization dataFromPropertyList:aFoundationObject
                                                                 format:kCFPropertyListBinaryFormat_v1_0 // was NSPropertyListXMLFormat_v1_0
                                                       errorDescription:&errorString];
    if ( nil == theData )
    {
        LOG((@"NSData +dataFromFoundationObject: error:%@", errorString));
        [errorString release];
        return nil;
    }
    
    return theData;
}

+ (NSString *)encodedStringFromFoundationObject:(id)aFoundationObject
{
    return [[self dataFromFoundationObject:aFoundationObject] base64Encoding];
}

/*! unserializes NSData, NSString, NSNumber, NSDate, NSArray, or NSDictionary from NSData */
+ (id)foundationObjectFromData:(NSData *)inData
{
    NSString *errorString;    
    id theFoundationObject = [NSPropertyListSerialization propertyListFromData:inData
                                                              mutabilityOption:NSPropertyListImmutable
                                                                        format:nil
                                                              errorDescription:&errorString];
    if ( nil == theFoundationObject )
    {
        LOG((@"NSData -foundationObjectFromData: error:%@", errorString));
        [errorString release];
        return nil;
    }
    
    return theFoundationObject;
}

+ (id)mutableFoundationObjectFromData:(NSData *)inData
{
    NSString *errorString;    
    id theFoundationObject = [NSPropertyListSerialization propertyListFromData:inData
                                                              mutabilityOption:NSPropertyListMutableContainersAndLeaves
                                                                        format:nil
                                                              errorDescription:&errorString];
    if ( nil == theFoundationObject )
    {
        LOG((@"NSData -foundationObjectFromData: error:%@", errorString));
        [errorString release];
        return nil;
    }
    
    return theFoundationObject;
}

+ (id)foundationObjectFromEncodedString:(NSString *)aBase64EncodedString
{
    return [self foundationObjectFromData:[NSData dataWithBase64EncodedString:aBase64EncodedString]];
}

+ (id)mutableFoundationObjectFromEncodedString:(NSString *)aBase64EncodedString
{
    return [self mutableFoundationObjectFromData:[NSData dataWithBase64EncodedString:aBase64EncodedString]];
}

// Hash function, by DamienBob  .... from CocoaDev

#include <openssl/sha.h>

#define SHA1_CTX			SHA_CTX
#define SHA1_DIGEST_LENGTH	SHA_DIGEST_LENGTH

- (NSData*) sha1Digest
{
	SHA1_CTX ctx;
	unsigned char digest[SHA1_DIGEST_LENGTH];
	SHA1_Init(&ctx);
	SHA1_Update(&ctx, [self bytes], [self length]);
	SHA1_Final(digest, &ctx);
	return [NSData dataWithBytes:digest length:SHA1_DIGEST_LENGTH];
}

- (NSString*) sha1DigestString
{
	static char __HEHexDigits[] = "0123456789abcdef";
	unsigned char digestString[2*SHA1_DIGEST_LENGTH];
	unsigned int i;
	SHA1_CTX ctx;
	unsigned char digest[SHA1_DIGEST_LENGTH];
	SHA1_Init(&ctx);
	SHA1_Update(&ctx, [self bytes], [self length]);
	SHA1_Final(digest, &ctx);
	for(i=0; i<SHA1_DIGEST_LENGTH; i++)
	{
		digestString[2*i]   = __HEHexDigits[digest[i] >> 4];
		digestString[2*i+1] = __HEHexDigits[digest[i] & 0x0f];
	}
	return [[[NSString alloc] initWithBytes:(const char *)digestString length:(unsigned)2*SHA1_DIGEST_LENGTH encoding:NSASCIIStringEncoding] autorelease];
}

#define DIGESTDATALENGTH 8192

- (NSString *)partiallyDigestString
{
	unsigned int length = [self length];
	unsigned int lengthToDigest = MIN(length, (unsigned int)DIGESTDATALENGTH);
	NSData *firstPart = [self subdataWithRange:NSMakeRange(0,lengthToDigest)];
	NSString *digest = [firstPart sha1DigestString];
	NSString *result = [NSString stringWithFormat:@"%@-%x", digest, length];
	return result;
}

+ (NSString *)partiallyDigestStringFromContentsOfFile:(NSString *)aPath
{
	NSString *result = @"";
	id fileHandle = [NSFileHandle fileHandleForReadingAtPath:aPath];
	if (fileHandle)
	{
		NSData *data = [fileHandle readDataOfLength:DIGESTDATALENGTH];
		NSString *digest = [data sha1DigestString];
		
		[fileHandle closeFile];
		
		// Get file length
		NSDictionary *attr = [[NSFileManager defaultManager] fileAttributesAtPath:aPath traverseLink:YES];
		NSNumber *fileSizeNum = [attr objectForKey:NSFileSize];
		long long fileSize = [fileSizeNum longLongValue];
		result = [NSString stringWithFormat:@"%@-%llx", digest, fileSize];
	}
	return result;
}

/*
	bzip2 decompression and compression
	Original Source: <http://cocoa.karelia.com/Foundation_Categories/NSData/bzip2_decompression.m>
	(See copyright notice at <http://cocoa.karelia.com>)
	 */

/*"	decompress the file to the given specified path (of the destination file).  Does not decompress tar archive.  Returns 0 or greater if OK; negative is an error code.  You will need to link against libbz2.a, either the one included in Jaguar, or wrapped and linked into your framework/application bundle.
"*/
- (int) decompressBzip2ToPath:(NSString *)inPath;
{
	// First, create all the sub-directories as needed
	
	NSError *error = nil;
	NSString *containerPath = [inPath stringByDeletingLastPathComponent];
	BOOL ok = [[NSFileManager defaultManager] createDirectoryAtPath:containerPath
										withIntermediateDirectories:YES
														 attributes:nil
															  error:&error];
	if (!ok)
	{
		return BZ_IO_ERROR;	// we don't have a way to 
	}
	
	int verbosity = 0;
	int small = 0;			// don't use small-memory model
	int bufferSize = 10240;	//	How many bytes to write out at a time
	
	char *buf = malloc(bufferSize);
	const char *pathName = [[NSFileManager defaultManager] fileSystemRepresentationWithPath:inPath];
	
	FILE*   	f = fopen ( pathName, "w" );
	if (nil == f)
	{
		return BZ_IO_ERROR;
	}
	
	// use trio BZ2_bzDecompressInit, BZ2_bzDecompress and BZ2_bzDecompressEnd for decompression.
	int ret = BZ_OK;
	bz_stream strm;
	strm.bzalloc = NULL;
	strm.bzfree = NULL;
	strm.opaque = NULL;
	ret = BZ2_bzDecompressInit ( &strm, verbosity, small );
	if (ret != BZ_OK) return ret;
	strm.next_in = (char *)[self bytes];		// the compressed data
	strm.avail_in = [self length];		// how much to read
	while (BZ_OK == ret)
	{
		strm.next_out = buf;				// buffer to write into
		strm.avail_out = bufferSize;		// how much is available in buffer
		ret = BZ2_bzDecompress ( &strm );
		
		// Write out the bufs if we had no error.
		if (BZ_OK == ret || BZ_STREAM_END == ret)
		{
			size_t written = fwrite(buf, sizeof(char), strm.next_out - buf, f);
			if (0 == written)
			{
				NSLog(@"Wrote zero bytes");
			}
		}
	}
	fclose(f);
	free (buf);
	BZ2_bzDecompressEnd ( &strm );
	return ret;
}

/* Compress data.  NOT ACTUALLY EVER TESTED;   PLEASE SEND FEEDBACK ON THIS! */

- (NSData *) compressBzip2
{
	NSData *result = nil;
	int blockSize100k = 5; // NOT SURE WHAT BEST VALUE IS.
	int verbosity = 0;		// SHOULD BE ZERO TO BE QUIET.
	int workFactor = 0;		// 0 = USE THE DEFAULT VALUE
	unsigned int sourceLength = [self length];
	unsigned int destLength = 1.01 * sourceLength + 600;	// Official formula, Big enough to hold output.  Will change to real size.
	char *dest = malloc(destLength);
	char *source = (char *) [self bytes];
	int returnCode = BZ2_bzBuffToBuffCompress( dest, &destLength, source, sourceLength, blockSize100k, verbosity, workFactor );
	
	if (BZ_OK == returnCode)
	{
		result = [NSData dataWithBytesNoCopy:dest length:destLength];
		// Do not free bytes; NSData now owns it.
	}
	else
	{
		NSLog(@"-[NSData decompressBzip2]: error %d returned",returnCode);
		free(dest);
	}
	return result;
}

// BZIP DOCUMENTATION:  ftp://sources.redhat.com/pub/bzip2/docs/manual_3.html


// Similar to gzip deflate from http://www.cocoadev.com/index.pl?NSDataCategory
// but gzip instead of zlib format by using deflateInit2, see http://www.gzip.org/zlib/zlib_faq.html#faq20

 
- (NSData *)compressGzip
{
	if ([self length] == 0) return self;
	
	z_stream strm;
	
	strm.zalloc = Z_NULL;
	strm.zfree = Z_NULL;
	strm.opaque = Z_NULL;
	strm.total_out = 0;
	strm.next_in=(Bytef *)[self bytes];
	strm.avail_in = [self length];
	
	if (Z_OK != deflateInit2(&strm, // strm
							 Z_DEFAULT_COMPRESSION, // level
							 Z_DEFLATED, // method
							 15 + 16, // windowBits ... 8 to 15; higher = better compression & more memory.  Add 16 = gzip
							 8, // memLevel 1 = min memory, slow; 9 = max memory, fast
							 Z_DEFAULT_STRATEGY // strategy
							 )) return nil;
	
	NSMutableData *compressed = [NSMutableData dataWithLength:16384];  // 16K chuncks for expansion
	
	do {
		
		if (strm.total_out >= [compressed length])
			[compressed increaseLengthBy: 16384];
		
		strm.next_out = [compressed mutableBytes] + strm.total_out;
		strm.avail_out = [compressed length] - strm.total_out;
		
		deflate(&strm, Z_FINISH);  
		
	} while (strm.avail_out == 0);
	
	deflateEnd(&strm);
	
	[compressed setLength: strm.total_out];
	OBPOSTCONDITION([compressed length]);
	return [NSData dataWithData: compressed];
}



@end
