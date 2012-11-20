//
//  EvernotePlugin.m
//  Evernote
//
//  Created by Atsushi Nagase on 5/24/12.
//  Copyright (c) 2012 LittleApps Inc. All rights reserved.
//

#import "EvernotePlugin-APIKey.h"
#import "EvernotePlugin.h"
#import "AuthWindowController.h"
#import "EvernoteSDK.h"
#import "EvernoteSession.h"
#import "EvernoteSession+coda.h"
#import "EvernoteNoteStore.h"
#import "EDAM.h"
#import "NSString+HTML.h"
#import "NSString+Sundown.h"
#import "NSData+md5.h"

#define kENMLPrefix @"<?xml version=\"1.0\" encoding=\"UTF-8\"?><!DOCTYPE en-note SYSTEM \"http://xml.evernote.com/pub/enml2.dtd\"><en-note style=\"word-wrap: break-word; -webkit-nbsp-mode: space; -webkit-line-break: after-white-space;\">"
#define kENMLSuffix @"</en-note>"

@interface EvernotePlugin ()

- (id)initWithPlugInController:(CodaPlugInsController*)aController;
- (void)createNote:(id)sender;
- (void)createNoteFromSelection:(id)sender;
- (void)createMarkdownNote:(id)sender;
- (void)createMarkdownNoteFromSelection:(id)sender;
- (void)createNote:(BOOL)isSelected isMarkdown:(BOOL)isMarkdown withSender:(id)sender;
- (void)sendPendingNote;
- (void)showAuthWindow:(id)sender;
- (NSString *)enMediaTagWithResource:(EDAMResource *)src width:(CGFloat)width height:(CGFloat)height;

@property (nonatomic, strong) CodaPlugInsController *pluginController;
@property (nonatomic, readonly) AuthWindowController *authWindowController;
@property (nonatomic, strong) EDAMNote *pendingNote;

@end

@implementation EvernotePlugin

@synthesize pluginController = _pluginController
, authWindowController = _authWindowController
, pendingNote = _pendingNote
;

#pragma mark - CodaPlugin Methods

- (NSString *)name { return @"Evernote"; }

- (id)initWithPlugInController:(CodaPlugInsController*)aController
                  plugInBundle:(NSObject <CodaPlugInBundle> *)plugInBundle {
  return self = [self initWithPlugInController:aController];
}

- (id)initWithPlugInController:(CodaPlugInsController *)aController
                        bundle:(NSBundle *)yourBundle {
  return self = [self initWithPlugInController:aController];
}

- (id)initWithPlugInController:(CodaPlugInsController*)aController {
  if(self=[self init]) {
    self.pluginController = aController;
    [EvernoteSession setSharedSessionHost:kENHost
                              consumerKey:kENConsumerKey
                           consumerSecret:kENConsumerSecret];
    
    [aController registerActionWithTitle:NSLocalizedString(@"Clip file content", nil)
                   underSubmenuWithTitle:nil
                                  target:self
                                selector:@selector(createNote:)
                       representedObject:nil
                           keyEquivalent:@"^~@e"
                              pluginName:self.name];
    
    
    [aController registerActionWithTitle:NSLocalizedString(@"Clip selection", nil)
                   underSubmenuWithTitle:nil
                                  target:self
                                selector:@selector(createNoteFromSelection:)
                       representedObject:nil
                           keyEquivalent:@"$^~@e"
                              pluginName:self.name];
    
    [aController registerActionWithTitle:NSLocalizedString(@"Clip Markdown rendered file content", nil)
                   underSubmenuWithTitle:nil
                                  target:self
                                selector:@selector(createMarkdownNote:)
                       representedObject:nil
                           keyEquivalent:@"^~@m"
                              pluginName:self.name];
    
    
    [aController registerActionWithTitle:NSLocalizedString(@"Clip Markdown rendered selection", nil)
                   underSubmenuWithTitle:nil
                                  target:self
                                selector:@selector(createMarkdownNoteFromSelection:)
                       representedObject:nil
                           keyEquivalent:@"$^~@m"
                              pluginName:self.name];
    
    [aController registerActionWithTitle:NSLocalizedString(@"Logout", nil)
                                  target:self
                                selector:@selector(logout:)];
  }
  return self;
}

- (BOOL)respondsToSelector:(SEL)aSelector {
  CodaTextView *textView = [self.pluginController focusedTextView:self];
  NSString *code = nil;
  if(aSelector == @selector(createNote:) ||
     aSelector == @selector(createMarkdownNote:)) {
    code = textView.string;
    return code && code.length > 0;
  }
  if(aSelector == @selector(createNoteFromSelection:) ||
     aSelector == @selector(createMarkdownNoteFromSelection:)) {
    code = textView.selectedText;
    return code && code.length > 0;
  }
  if(aSelector == @selector(logout:))
    return [EvernoteSession sharedSession].isAuthenticated;
  return [super respondsToSelector:aSelector];
}

#pragma mark - Accessors

- (AuthWindowController *)authWindowController {
  if(nil==_authWindowController) {
    _authWindowController = [[AuthWindowController alloc] initWithPlugin:self];
  }
  return _authWindowController;
}


#pragma mark - Actions

- (void)showAuthWindow:(id)sender {
  [self.authWindowController showWindow:self.authWindowController];
  [[EvernoteSession sharedSession] authenticateWithCompletionHandler:^(NSError *error) {
    [self sendPendingNote];
  }];
}

- (void)createNote:(id)sender {
  [self createNote:NO isMarkdown:NO withSender:sender];
}

- (void)createNoteFromSelection:(id)sender {
  [self createNote:YES isMarkdown:NO withSender:sender];
}

- (void)createMarkdownNote:(id)sender {
  [self createNote:NO isMarkdown:YES withSender:sender];
}

- (void)createMarkdownNoteFromSelection:(id)sender {
  [self createNote:YES isMarkdown:YES withSender:sender];
}

- (void)createNote:(BOOL)isSelected isMarkdown:(BOOL)isMarkdown withSender:(id)sender {
  CodaTextView *textView = [self.pluginController focusedTextView:self];
  NSString *content = isSelected ? textView.selectedText : textView.string;
  EvernoteSession *session = [EvernoteSession sharedSession];
  EDAMNote *note = [[EDAMNote alloc] init];
  NSMutableString* contentStr = [[NSMutableString alloc] initWithString:kENMLPrefix];
  content = isMarkdown ?
  [content sd_renderedStringWithRenderFlags:HTML_SKIP_HTML|HTML_USE_XHTML|HTML_ESCAPE] :
  [NSString stringWithFormat:@"<pre>%@</pre>",
   [content stringByEncodingHTMLEntities]];
  [contentStr appendString:content];
  [contentStr appendString:kENMLSuffix];
  note.content = [contentStr copy];
  if(textView.path) {
    NSURL *URL = [[NSURL alloc] initFileURLWithPath:textView.path isDirectory:NO];
    note.title = URL.lastPathComponent;
  }
  self.pendingNote = note;
  if(!session.isAuthenticated)
    [self showAuthWindow:self];
  else
    [self sendPendingNote];
}

- (void)logout:(id)sender {
  [[EvernoteSession sharedSession] logout];
}

- (void)sendPendingNote {
  dispatch_async(dispatch_queue_create("", NULL), ^{
    EvernoteNoteStore *noteStore = [EvernoteNoteStore noteStore];
    if(!(self.pendingNote.title.length > 0))
      [self.pendingNote setTitle:@"Untitled"];
    NSString *content = self.pendingNote.content;
    NSError *error = nil;
    NSMutableArray *resources = [NSMutableArray array];
    NSRegularExpression *re1 = [NSRegularExpression regularExpressionWithPattern:@"<img[^>]+>" options:NSRegularExpressionCaseInsensitive error:&error];
    if(error) [NSException raise:error.domain format:@"%@", error.localizedDescription];
    NSRegularExpression *re2 = [NSRegularExpression regularExpressionWithPattern:@"(src|alt|title)=\"([^\"]+)\"" options:NSRegularExpressionCaseInsensitive error:&error];
    if(error) [NSException raise:error.domain format:@"%@", error.localizedDescription];
    NSTextCheckingResult *match1 = nil;
    do {
      match1 = [re1 firstMatchInString:content options:0 range:NSMakeRange(0, content.length)];
      if(!match1||match1.range.location==NSNotFound) break;
      NSString *img = [content substringWithRange:match1.range];
      NSArray *matches2 = [re2 matchesInString:img options:0 range:NSMakeRange(0, img.length)];
      NSImage *image = nil;
      NSString *imageURL = nil;
      for (NSTextCheckingResult *match2 in matches2) {
        if(match2.numberOfRanges == 3) {
          NSString *k = [img substringWithRange:[match2 rangeAtIndex:1]];
          NSString *v = [img substringWithRange:[match2 rangeAtIndex:2]];
          if([k isEqualToString:@"src"]) {
            imageURL = v;
            image = [[NSImage alloc] initWithContentsOfURL:[NSURL URLWithString:imageURL]];
            break;
          }
        }
      }
      if(!image)
        content = [content stringByReplacingCharactersInRange:match1.range withString:@""];
      else {
        EDAMResource *img = [[EDAMResource alloc] init];
        img.attributes.sourceURL = imageURL;
        NSData *rawimg = [NSBitmapImageRep representationOfImageRepsInArray:image.representations usingType:NSJPEGFileType properties:[NSDictionary dictionaryWithObject:[NSDecimalNumber numberWithFloat:0.8] forKey:NSImageCompressionFactor]];
        EDAMData *imgd = [[EDAMData alloc] initWithBodyHash:rawimg size:(int)[rawimg length] body:rawimg];
				[img setData:imgd];
				[img setRecognition:imgd];
				[img setMime:@"image/jpeg"];
        [resources addObject:img];
        content = [content stringByReplacingCharactersInRange:match1.range withString:[self enMediaTagWithResource:img width:image.size.width height:image.size.height]];
      }
    } while(YES);
    
    self.pendingNote.content = content;
    self.pendingNote.resources = resources;
    [noteStore
     createNote:self.pendingNote
     success:^(EDAMNote *note) {
       NSWorkspace *ws = [NSWorkspace sharedWorkspace];
       [[EvernoteUserStore userStore]
        getUserWithSuccess:^(EDAMUser *user) {
          NSURL *URL = [NSURL URLWithString:
                        [NSString stringWithFormat:@"evernote:///view/%d/%@/%@//",
                         user.id, user.shardId, note.guid]];
          if(![ws openURL:URL]) {
            URL = [NSURL URLWithString:
                   [NSString stringWithFormat:@"https://%@/view/%@", kENHost, note.guid]];
            [ws openURL:URL];
          }
        }
        failure:^(NSError *error) {
          
        }];
       
       
     }
     failure:^(NSError *error) {
       [NSAlert alertWithError:error];
       NSAlert *alert = [NSAlert alertWithError:error];
       [alert addButtonWithTitle:@"OK"];
       [alert setAlertStyle:NSWarningAlertStyle];
       [alert beginSheetModalForWindow:nil modalDelegate:nil didEndSelector:nil contextInfo:nil];
     }];
    self.pendingNote = nil;
  });
  
}

- (NSString *)enMediaTagWithResource:(EDAMResource *)src width:(CGFloat)width height:(CGFloat)height {
	NSString *sizeAtr = width > 0 && height > 0 ? [NSString stringWithFormat:@"height=\"%.0f\" width=\"%.0f\" ",height,width]:@"";
	return [NSString stringWithFormat:@"<en-media type=\"%@\" %@hash=\"%@\"/>",src.mime,sizeAtr,[src.data.body md5]];
}

@end
