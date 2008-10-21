//
//  KT.h
//  Sandvox
//
//  Copyright (c) 2004-2008, Karelia Software. All rights reserved.
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

// KT.h lists enums and strings that are used throughout Sandvox
// they can only be #imported once, so they are kept separately from Sandvox.h

// LocalizedStringInThisBundle is really for use by plugins,
// But WARNING -- it won't work in Category Methods, since the class will have the wrong bundle.
// Code in Sandvox.app should always just use standard NSLocalized* macros
#define LocalizedStringInThisBundle(key, comment) [[NSBundle bundleForClass:[self class]] localizedStringForKey:(key) value:@"" table:nil]

// Description Forthcoming
typedef enum {
    KTCollectionSortUnspecified = -1,		// used internally
	KTCollectionUnsorted = 0, 
    KTCollectionSortAlpha,
    KTCollectionSortLatestAtBottom,
	KTCollectionSortLatestAtTop,		// = 3 ... default
	KTCollectionSortReverseAlpha,
} KTCollectionSortType;

// Description Forthcoming
typedef enum {
	KTSummarizeAutomatic = 1,
	KTSummarizeMostRecent,
	KTSummarizeRecentList,
	KTSummarizeAlphabeticalList,
	KTSummarizeFirstItem	// this was added later, that's why it's at the end
} KTCollectionSummaryType;

// Description Forthcoming
typedef enum {
	KTTimestampCreationDate = 1,
	KTTimestampModificationDate
} KTTimestampType;

// Description Forthcoming
typedef enum {
	KTHTML401DocType = 0,
	KTXHTMLTransitionalDocType,
	KTXHTMLStrictDocType,
	KTXHTML11DocType
} KTDocType;

// strings
extern NSString *kKTModelVersion;
extern NSString *kKTModelVersion_ORIGINAL;
extern NSString *kKTModelMaximumVersion;
extern NSString *kKTModelMinimumVersion;

extern NSString *kKTDocumentType;
extern NSString *kKTDocumentExtension;
extern NSString *kKTDocumentUTI; // 1.5+ documents
extern NSString *kKTDocumentUTI_ORIGINAL; // 1.0-1.2 documents

extern NSString *kKTIndexExtension;
extern NSString *kKTElementExtension;
extern NSString *kKTDesignExtension;

extern NSString *kKTMetadataAppCreatedVersionKey;
extern NSString *kKTMetadataAppLastSavedVersionKey;
extern NSString *kKTMetadataModelVersionKey;

extern NSString *kKTOutlineDraggingPboardType;
extern NSString *kKTPagesPboardType;
extern NSString *kKTPageletsPboardType;


extern NSString *kKTDesignChangedNotification;
extern NSString *kKTInfoWindowMayNeedRefreshingNotification; // not currently used
extern NSString *kKTItemSelectedNotification;
extern NSString *kKTSiteStructureDidChangeNotification;

extern NSString *kKTInternalImageClassName;

extern NSString *kKTDefaultMediaPath;
extern NSString *kKTDefaultResourcesPath;

extern NSString *kKTDataSourceFileName;	// name of file, with extension -- may not be on file system!
extern NSString *kKTDataSourceFilePath;	// path of actual file
extern NSString *kKTDataSourceTitle;	// title other than the file name, if it's known
extern NSString *kKTDataSourceNil;      // indicate an empty datasource, return nil
extern NSString *kKTDataSourceRecurse;
extern NSString *kKTDataSourceCaption;
extern NSString *kKTDataSourceURLString;
extern NSString *kKTDataSourceImageURLString;
extern NSString *kKTDataSourcePreferExternalImageFlag;
extern NSString *kKTDataSourceShouldIncludeLinkFlag;
extern NSString *kKTDataSourceLinkToOriginalFlag;
extern NSString *kKTDataSourceFeedURLString;
extern NSString *kKTDataSourcePlugin;
extern NSString *kKTDataSourceImage;
extern NSString *kKTDataSourceData;
extern NSString *kKTDataSourceUTI;
extern NSString *kKTDataSourceString;
extern NSString *kKTDataSourceCreationDate;
extern NSString *kKTDataSourceKeywords;
extern NSString *kKTDataSourcePasteboard;

extern NSString *kKTPageIDDesignator;

extern NSString *kKTSelectedObjectsKey;
extern NSString *kKTSelectedObjectsClassNameKey;

extern NSString *kKTHostSetupErrorDomain;
extern NSString *kKTConnectionErrorDomain;
extern NSString *kKTDataMigrationErrorDomain;

extern NSString *kKTTemplateParserException;
