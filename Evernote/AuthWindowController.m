//
//  AuthWindowController.m
//  Evernote
//
//  Created by Atsushi Nagase on 5/24/12.
//  Copyright (c) 2012 LittleApps Inc. All rights reserved.
//

#import "AuthWindowController.h"
#import "EvernotePlugin.h"
#import "EvernoteSession.h"

@interface AuthWindowController ()

@end

static AuthWindowController *_sharedWindowController;

@implementation AuthWindowController
@synthesize progressIndicator
, webView
, plugin = _plugin
;

+ (AuthWindowController *)sharedWindowController {
  return _sharedWindowController;
}

#pragma mark -

- (id)initWithPlugin:(EvernotePlugin *)plugin {
  if(self=[super initWithWindowNibName:@"AuthWindowController" owner:self]) {
    self.plugin = plugin;
  }
  return self;
}

#pragma mark - NSWindowController Methods

- (void)windowDidLoad {
  [super windowDidLoad];
}

- (void)showWindow:(id)sender {
  if(_sharedWindowController)
    [_sharedWindowController close];
  _sharedWindowController = self;
  self.window.alphaValue = 0;
  [super showWindow:self];
  [self.window makeKeyAndOrderFront:self];
  [self.progressIndicator startAnimation:self];
  while (self.window.alphaValue < 1) {
    self.window.alphaValue += 0.1;
    [NSThread sleepForTimeInterval:0.020];
  }
}

- (void)close {
  _sharedWindowController = nil;
  while (self.window.alphaValue > 0) {
    self.window.alphaValue -= 0.1;
    [NSThread sleepForTimeInterval:0.020];
  }
  [super close];
}

#pragma mark - WebResourceLoadDelegate Methods

- (NSURLRequest *)webView:(WebView *)sender
                 resource:(id)identifier willSendRequest:(NSURLRequest *)request
         redirectResponse:(NSURLResponse *)redirectResponse
           fromDataSource:(WebDataSource *)dataSource {
  EvernoteSession *session = [EvernoteSession sharedSession];
  if([session handleOpenURL:request.URL]) {
    [self close];
    return nil;
  }
  return request;
}

- (void)webView:(WebView *)sender resource:(id)identifier didFinishLoadingFromDataSource:(WebDataSource *)dataSource {
  [self.progressIndicator stopAnimation:self];
}


@end
