//
//  NSData+KTExtensions.h
//  KTComponents
//
//  Copyright (c) 2005-2006, Karelia Software. All rights reserved.
//
//  THIS SOFTWARE IS PROVIDED BY KARELIA SOFTWARE AND ITS CONTRIBUTORS "AS-IS"
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

#import <Foundation/Foundation.h>


@interface NSData ( KTExtensions )

+ (NSData *)dataWithBase64EncodedString:(NSString *)base64String;
- (NSString *)base64Encoding;

+ (NSData *)dataFromXMLPropertyList:(NSString *)aPropertyList;

+ (NSData *)dataFromFoundationObject:(id)aFoundationObject;
+ (NSString *)encodedStringFromFoundationObject:(id)aFoundationObject;

+ (id)foundationObjectFromData:(NSData *)inData;
+ (id)mutableFoundationObjectFromData:(NSData *)inData;

+ (id)foundationObjectFromEncodedString:(NSString *)aBase64EncodedString;
+ (id)mutableFoundationObjectFromEncodedString:(NSString *)aBase64EncodedString;

- (NSString*) sha1DigestString;
- (NSData*) sha1Digest;

- (NSString *)partiallyDigestString;
+ (NSString *)partiallyDigestStringFromContentsOfFile:(NSString *)aPath;

- (int) decompressBzip2ToPath:(NSString *)inPath;
- (NSData *) compressBzip2;
- (NSData *)compressGzip;


- (BOOL)containsFaviconImageData;
- (BOOL)containsGIFImageData;
- (BOOL)containsJPEGImageData;
- (BOOL)containsPNGImageData;
- (BOOL)containsTIFFImageData;


@end
