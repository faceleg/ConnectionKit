//
//  KTHTMLParser.h
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
#import "KTTemplateParser.h"

#import "KTDocument.h"
#import "KTWebViewComponent.h"


@class KTDocument, KTHTMLParserMasterCache, KTMediaFileUpload, KTHTMLTextBlock;
@class KTAbstractPage;
@class KTMediaFile;


@interface KTHTMLParser : KTTemplateParser
{
	KTAbstractPage			*myCurrentPage;
	KTHTMLGenerationPurpose	myHTMLGenerationPurpose;
	BOOL					myIncludeStyling;
	NSNumber				*myLiveDataFeeds;
}

- (id)initWithPage:(KTAbstractPage *)page;	// Convenience method that parses the whole page

// Accessors
- (KTAbstractPage *)currentPage;
- (void)setCurrentPage:(KTAbstractPage *)page;

- (KTHTMLGenerationPurpose)HTMLGenerationPurpose;
- (void)setHTMLGenerationPurpose:(KTHTMLGenerationPurpose)purpose;
- (BOOL)includeStyling;
- (void)setIncludeStyling:(BOOL)includeStyling;

- (BOOL)liveDataFeeds;
- (void)setLiveDataFeeds:(BOOL)flag;

// Fucntions
- (NSString *)widthStringOfMediaFile:(KTMediaFile *)mediaFile;
- (NSString *)heightStringOfMediaFile:(KTMediaFile *)mediaFile;

- (NSString *)pathToObject:(id)anObject;

// Prebuilt templates
+ (NSString *)calloutContainerTemplateHTML;
- (NSString *)calloutContainerTemplateHTML;

@end


@interface KTHTMLParser (Text)
- (KTHTMLTextBlock *)textblockForKeyPath:(NSString *)keypath ofObject:(id)object
									  flags:(NSArray *)flags
								    HTMLTag:(NSString *)tag
						  graphicalTextCode:(NSString *)GTCode
								  hyperlink:(KTAbstractPage *)hyperlink;
@end


@interface NSObject (KTHTMLParserDelegate)
- (void)HTMLParser:(KTHTMLParser *)parser didEncounterResourceFile:(NSString *)resourcePath;
- (void)HTMLParser:(KTHTMLParser *)parser didParseMediaFile:(KTMediaFile *)mediaFile upload:(KTMediaFileUpload *)upload;	
- (void)HTMLParser:(KTHTMLParser *)parser didParseTextBlock:(KTHTMLTextBlock *)textBlock;
@end
