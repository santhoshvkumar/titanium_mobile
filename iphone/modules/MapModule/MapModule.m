/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import <TitaniumBasicModule.h>
#import <MapKit/MapKit.h>

@interface MapViewAnnotation : NSObject<MKAnnotation>
{
	NSString *title;
	NSString *subtitle;
	BOOL animate;
	MKPinAnnotationColor pincolor;
	CLLocationCoordinate2D coordinate;
	NSString *leftButton;
	NSString *rightButton;
}
-(id)init:(CLLocationCoordinate2D)coord;
@property (nonatomic, readonly) CLLocationCoordinate2D coordinate;
@property (nonatomic) BOOL animate;
@property (nonatomic) MKPinAnnotationColor pincolor;
@property (nonatomic,retain) NSString* title;
@property (nonatomic,retain) NSString* subtitle;
@property (nonatomic,retain) NSString* leftButton;
@property (nonatomic,retain) NSString* rightButton;
@end

@implementation MapViewAnnotation

@synthesize animate,pincolor,coordinate,title,subtitle;
@synthesize leftButton,rightButton;

-(id)init:(CLLocationCoordinate2D)coord
{
	if (self = [super init])
	{
		coordinate = coord;
	}
	return self;
}
-(void)dealloc
{
	[title release];
	[subtitle release];
	[leftButton release];
	[rightButton release];
	[super dealloc];
}
@end

@interface MapViewController : TitaniumContentViewController<MKMapViewDelegate, MKReverseGeocoderDelegate, CLLocationManagerDelegate> {
	NSString *token;
	NSString *pageToken;
	MKMapView *view;
	NSUInteger mapType;
	CLLocationCoordinate2D coord;
	MKCoordinateSpan span;
	MKCoordinateRegion region;
	bool animate;
	bool regionFit;
	bool userLocation;
	NSMutableArray *annotations;
}
-(void)render;
@end

@interface MapModule : TitaniumBasicModule {
	NSMutableDictionary *views;
}
-(void)registerView:(MapViewController*) controller forToken:(NSString*)token;
-(void)unregisterView:(NSString*)token;
-(MapViewController*)getView:(NSString*)token;
@end



@implementation MapViewController

- (void)dealloc 
{
	MapModule * mod = (MapModule *) [[TitaniumHost sharedHost] moduleNamed:@"MapModule"];
	[mod unregisterView:token];
	[token release];
	[pageToken release];
	[view release];
	[super dealloc];
}

-(void)setMapType:(NSNumber*)type
{
	view.mapType = [type unsignedIntegerValue];
}

-(void)setLocation:(NSDictionary*)location
{
	//comes in like region: {latitude:100, longitude:100, latitudeDelta:0.5, longitudeDelta:0.5}
	id lat = [location objectForKey:@"latitude"];
	id lon = [location objectForKey:@"longitude"];
	id latdelta = [location objectForKey:@"latitudeDelta"];
	id londelta = [location objectForKey:@"longitudeDelta"];
	if (lat)
	{
		coord.latitude = [lat doubleValue];
	}
	if (lon)
	{
		coord.longitude = [lon doubleValue];
	}
	if (latdelta)
	{
		span.latitudeDelta = [latdelta doubleValue];
	}
	if (londelta)
	{
		span.longitudeDelta = [londelta doubleValue];
	}
	id an = [location objectForKey:@"animate"];
	if (an)
	{
		animate = [an boolValue];
	}
	id rf = [location objectForKey:@"regionFit"];
	if (rf)
	{
		regionFit = [rf boolValue];
	}
}

- (void) readState: (id) inputState relativeToUrl: (NSURL *) baseUrl
{
	// setup defaults
	span.latitudeDelta=.005;
	span.longitudeDelta=.005;
	
	NSDictionary *dict = (NSDictionary*)inputState;
	id mtype = [dict objectForKey:@"mapType"];
	if (mtype)
	{
		NSNumber *n = (NSNumber*)mtype;
		mapType = [n unsignedIntegerValue];
		if (view)
		{
			view.mapType = mapType;
		}
	}
	id reg = [dict objectForKey:@"region"];
	
	if ([reg isKindOfClass:[NSDictionary class]])
	{
		[self setLocation:reg];
	}
	
	id an = [dict objectForKey:@"animate"];
	if (an)
	{
		animate = [an boolValue];
	}
	
	id rf = [dict objectForKey:@"regionFit"];
	if (rf)
	{
		regionFit = [rf boolValue];
	}
	
	id ul = [dict objectForKey:@"userLocation"];
	if (ul)
	{
		userLocation = [ul boolValue];
	}
	
	TitaniumHost *tiHost = [TitaniumHost sharedHost];
	
	id ant = [dict objectForKey:@"annotations"];
	if ([ant isKindOfClass:[NSArray class]])
	{
		NSArray *anno = (NSArray*)ant;
		annotations = [[NSMutableArray alloc] init];
		for (int c=0;c<[anno count];c++)
		{
			NSDictionary * value = (NSDictionary*)[anno objectAtIndex:c];
			CLLocationCoordinate2D l;
			l.latitude = [[value objectForKey:@"latitude"] doubleValue];
			l.longitude = [[value objectForKey:@"longitude"] doubleValue];
			MapViewAnnotation * loc = [[MapViewAnnotation alloc] init:l];
			loc.pincolor = [[value objectForKey:@"pincolor"] unsignedIntegerValue];
			loc.animate = [[value objectForKey:@"animate"] boolValue];
			loc.title = [value objectForKey:@"title"];
			loc.subtitle = [value objectForKey:@"subtitle"];
			id li = [value objectForKey:@"leftButton"];
			if (li)
			{
				loc.leftButton=(NSString*)li;
			}
			id ri = [value objectForKey:@"rightButton"];
			if (ri)
			{
				loc.rightButton=(NSString*)ri;
			}
			[annotations addObject:loc];
			[loc release];
		}
	}
	
	MapModule * mod = (MapModule *) [tiHost moduleNamed:@"MapModule"];
	token = [(NSString*)[dict objectForKey:@"_TOKEN"] retain];
	[mod registerView:self forToken:token];
	
	pageToken = [[[TitaniumHost sharedHost] currentThread] magicToken];
	region.center = coord;
	region.span = span;
}

- (void)render
{
	region.center = coord;
	region.span = span;
	[view setRegion:region animated:animate];
	if (regionFit)
	{
		[view regionThatFits:region];
	}
}

- (UIView *) view
{
	if (view ==  nil)
	{
		CGRect viewFrame;
		viewFrame.origin = CGPointZero;
		viewFrame.size = preferredViewSize;
		view = [[MKMapView alloc] initWithFrame:viewFrame];
		view.mapType = mapType;
		view.showsUserLocation=YES;
		view.delegate = self;
		view.userInteractionEnabled = YES;
		
		
		[view setAutoresizingMask:UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight];
		
		if (annotations && [annotations count]>0)
		{
			[view addAnnotations:annotations];
		}
		
		if (userLocation)
		{
			CLLocationManager *locationManager=[[CLLocationManager alloc] init];
			locationManager.delegate=self;
			locationManager.desiredAccuracy=kCLLocationAccuracyNearestTenMeters;
			[locationManager startUpdatingLocation];
		}
		else
		{
			[self performSelectorOnMainThread:@selector(render)
								   withObject:nil
								waitUntilDone:NO];
		}
	}
	return view;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
	NSString *action = (NSString*)context;
	
//	NSLog(@"[INFO] object key value = %@ for %@",keyPath,object);
	
	if([action isEqualToString:@"ANSELECTED"])
	{
		//BOOL flag = [[change valueForKey:@"new"] boolValue];
		if ([object isKindOfClass:[MKPinAnnotationView class]])
		{
			MKPinAnnotationView *pinview = (MKPinAnnotationView*)object;
			NSString *title = [[pinview reuseIdentifier] stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
			TitaniumHost * theHost = [TitaniumHost sharedHost];
			NSString * pathString = [self javaScriptPath];
			NSString * commandString = [NSString stringWithFormat:@"%@.onEvent('click',{source:'annotation',type:'click',title:'%@'});",pathString,title];	
			[theHost sendJavascript:commandString toPagesWithTokens:listeningWebContextTokens update:YES];
			
		}
	}
}

- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)aview calloutAccessoryControlTapped:(UIControl *)control
{
	if ([control isKindOfClass:[UIButton class]])
	{
		if (aview.leftCalloutAccessoryView == control)
		{
			NSString *title = [[aview reuseIdentifier] stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
			TitaniumHost * theHost = [TitaniumHost sharedHost];
			NSString * pathString = [self javaScriptPath];
			NSString * commandString = [NSString stringWithFormat:@"%@.onEvent('click',{source:'leftButton',type:'click',title:'%@'});",pathString,title];	
			[theHost sendJavascript:commandString toPagesWithTokens:listeningWebContextTokens update:YES];
		}
		else if (aview.rightCalloutAccessoryView == control)
		{
			NSString *title = [[aview reuseIdentifier] stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
			TitaniumHost * theHost = [TitaniumHost sharedHost];
			NSString * pathString = [self javaScriptPath];
			NSString * commandString = [NSString stringWithFormat:@"%@.onEvent('click',{source:'rightButton',type:'click',title:'%@'});",pathString,title];	
			[theHost sendJavascript:commandString toPagesWithTokens:listeningWebContextTokens update:YES];
		}
		else
		{
			NSLog(@"[INFO] clicked on center button");
		}
	}
}

-(UIButton*)makeButton:(NSString*)url
{
	int type = barButtonSystemItemForString(url);
	if (type == UITitaniumNativeItemNone)
	{
		TitaniumHost * theHost = [TitaniumHost sharedHost];
		UIImage *image = [theHost imageForResource:url];
		CGSize size = [image size];
		UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
		button.frame = CGRectMake(0,0,size.width,size.height);
		button.backgroundColor = [UIColor clearColor];
		[button setImage:image forState:UIControlStateNormal];
		[image autorelease];
		return button;
	}
	return [UIButton buttonWithType:type];
}

- (MKAnnotationView *) mapView:(MKMapView *)mapView viewForAnnotation:(id <MKAnnotation>) annotation
{
	if ([annotation isKindOfClass:[MapViewAnnotation class]])
	{
		MapViewAnnotation *ann = (MapViewAnnotation*)annotation;
		MKPinAnnotationView *annView =(MKPinAnnotationView*) [mapView dequeueReusableAnnotationViewWithIdentifier:[ann title]];
		if (annView==nil)
		{
			annView=[[MKPinAnnotationView alloc] initWithAnnotation:ann reuseIdentifier:[ann title]];
			annView.pinColor = [ann pincolor];
			annView.animatesDrop = [ann animate];
			annView.canShowCallout = YES;
			annView.calloutOffset = CGPointMake(-5, 5);
			annView.enabled = YES;
			if (ann.leftButton)
			{
				annView.leftCalloutAccessoryView = [self makeButton:ann.leftButton];
			}
			if (ann.rightButton)
			{
				annView.rightCalloutAccessoryView = [self makeButton:ann.rightButton];
			}
			annView.userInteractionEnabled = YES;
			[annView addObserver:self
					  forKeyPath:@"selected"
						 options:NSKeyValueObservingOptionNew
						 context:@"ANSELECTED"];
		}				

		return annView;
	}
	return nil;
}

/*
- (void)mapView:(MKMapView *)mapView didAddAnnotationViews:(NSArray *)views
{
	NSLog(@"[INFO] MapKit annotation view added");
}*/

- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated
{
	TitaniumHost * theHost = [TitaniumHost sharedHost];
	NSString * pathString = [self javaScriptPath];
	MKCoordinateRegion aregion = [mapView region];
	NSDictionary * props = [NSDictionary dictionaryWithObjectsAndKeys:
							@"regionChanged",@"type",
							[NSNumber numberWithDouble:aregion.center.latitude],@"latitude",
							[NSNumber numberWithDouble:aregion.center.longitude],@"longitude",
							[NSNumber numberWithDouble:aregion.span.latitudeDelta],@"latitudeDelta",
							[NSNumber numberWithDouble:aregion.span.longitudeDelta],@"longitudeDelta",nil];

	SBJSON *json = [[[SBJSON alloc] init] autorelease];
	NSString * commandString = [NSString stringWithFormat:@"%@.onEvent('regionChanged',%@);",pathString,[json stringWithObject:props error:nil]];	
	[theHost sendJavascript:commandString toPagesWithTokens:listeningWebContextTokens update:YES];
}

/*
- (void)mapViewWillStartLoadingMap:(MKMapView *)mapView
{
	NSLog(@"[INFO] MapKit load map started");
}*/

- (void)mapViewDidFailLoadingMap:(MKMapView *)mapView withError:(NSError *)error
{
	NSLog(@"[ERROR] MapKit load map failed = %@",[error description]);
	TitaniumHost * theHost = [TitaniumHost sharedHost];
	NSString * pathString = [self javaScriptPath];
	NSDictionary * props = [NSDictionary dictionaryWithObjectsAndKeys:
							@"error",@"type",
							[error description],@"message",nil];
	
	SBJSON *json = [[[SBJSON alloc] init] autorelease];
	NSString * commandString = [NSString stringWithFormat:@"%@.onEvent('error',%@);",pathString,[json stringWithObject:props error:nil]];	
	[theHost sendJavascript:commandString toPagesWithTokens:listeningWebContextTokens update:YES];
}

/*
- (void)mapViewDidFinishLoadingMap:(MKMapView *)mapView
{
	NSLog(@"[INFO] MapKit load map finished");
}*/

- (void)reverseGeocoder:(MKReverseGeocoder *)geocoder didFailWithError:(NSError *)error{
}

- (void)reverseGeocoder:(MKReverseGeocoder *)geocoder didFindPlacemark:(MKPlacemark *)placemark{
	[view addAnnotation:placemark];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation{
	
	region.center=newLocation.coordinate;
	[self performSelectorOnMainThread:@selector(render)
						   withObject:nil
						waitUntilDone:NO];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error{
}

@end


@implementation MapModule


-(void)registerView:(MapViewController*) controller forToken:(NSString*)token
{
	if (views==nil)
	{
		views = [[NSMutableDictionary alloc] init];
	}
	[views setObject:controller forKey:token];
}

-(void)unregisterView:(NSString*)token
{
	[views removeObjectForKey:token];
	
	// cleanup to conserve memory
	if ([views count]==0)
	{
		[views release];
		views = nil;
	}
}

-(MapViewController*)getView:(NSString*)token
{
	return [views objectForKey:token];
}

-(void)setLocation:(NSDictionary*)location token:(NSString*)token
{
	MapViewController *view = [self getView:token];
	if (view)
	{
		[view setLocation:location];
		[view performSelectorOnMainThread:@selector(render)
							   withObject:nil
							waitUntilDone:NO];
	}
}

-(void)setMapType:(NSNumber*)type token:(NSString*)token
{
	MapViewController *view = [self getView:token];
	if (view)
	{
		[view performSelectorOnMainThread:@selector(setMapType:)
							   withObject:type
							waitUntilDone:NO];
	}
}

-(void)addAnnotation:(NSDictionary*)dict
{
}

-(void) configure
{
	NSString * createViewString = @"function(args){var res=Ti.UI.createView(args);res._TYPE='map'; if(!Ti.Map._VIEWS){Ti.Map._VIEWS={};} Ti.Map._VIEWS[res._TOKEN]=res; res.onEvent=Ti._ONEVT; res._EVT = {click:[]}; res.addEventListener=Ti._ADDEVT; res.removeEventListener = Ti._REMEVT; res.setLocation=function(obj){Ti.Map._SETLOC(obj,res._TOKEN);}; res.setMapType=function(type){Ti.Map._SETMAP(type,res._TOKEN);}; return res;}";
	
	[self registerContentViewController:[MapViewController class] forToken:@"map"];
	[self bindProperty:@"STANDARD_TYPE" value:[NSNumber numberWithUnsignedInteger:MKMapTypeStandard]];
	[self bindProperty:@"SATELLITE_TYPE" value:[NSNumber numberWithUnsignedInteger:MKMapTypeSatellite]];
	[self bindProperty:@"HYBRID_TYPE" value:[NSNumber numberWithUnsignedInteger:MKMapTypeHybrid]];
	[self bindProperty:@"ANNOTATION_RED" value:[NSNumber numberWithUnsignedInteger:MKPinAnnotationColorRed]];
	[self bindProperty:@"ANNOTATION_GREEN" value:[NSNumber numberWithUnsignedInteger:MKPinAnnotationColorGreen]];
	[self bindProperty:@"ANNOTATION_PURPLE" value:[NSNumber numberWithUnsignedInteger:MKPinAnnotationColorPurple]];
	
	[self bindCode:@"createView" code:createViewString];
	[self bindFunction:@"_SETLOC" method:@selector(setLocation:token:)];
	[self bindFunction:@"_SETMAP" method:@selector(setMapType:token:)];
}

/**
 * @tiapi(method=True,name=Map.createView,version=0.8) create a google map view
 * @tiarg(for=Map.createView,type=object,name=properties) view properties
 * @tiresult(for=Map.createView,type=Map.MapView) the resulting map view
 *
 * @tiapi(property=True,name=Map.STANDARD_TYPE,version=0.8,type=int) constant representing the standard map type
 * @tiapi(property=True,name=Map.SATELLITE_TYPE,version=0.8,type=int) constant representing the satellite map type
 * @tiapi(property=True,name=Map.HYBRID_TYPE,version=0.8,type=int) constant representing the hybrid map type
 *
 * @tiapi(property=True,name=Map.ANNOTATION_RED,version=0.8,type=int) constant representing the annotation red pin type
 * @tiapi(property=True,name=Map.ANNOTATION_GREEN,version=0.8,type=int) constant representing the annotation green pin type
 * @tiapi(property=True,name=Map.ANNOTATION_PURPLE,version=0.8,type=int) constant representing the annotation purple pin type
 *
 *
 * @tiapi(method=True,name=Map.MapView.setLocation,version=0.8) set the location of the map
 * @tiarg(for=Map.MapView.setLocation,type=object,name=properties) location properties such as longitude, latitude
 *
 * @tiapi(method=True,name=Map.MapView.setMapType,version=0.8) set the map type
 * @tiarg(for=Map.MapView.setMapType,type=int,name=type) map
 *
 * @tiapi(method=True,name=Map.MapView.addEventListener,version=0.8) add event listener
 * @tiarg(for=Map.MapView.addEventListener,type=function,name=listener) function
 *
 * @tiapi(method=True,name=Map.MapView.removeEventListener,version=0.8) remove event listener
 * @tiarg(for=Map.MapView.addEventListener,type=function,name=listener) function
 *
 */

@end
