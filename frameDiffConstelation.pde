import blobDetection.*;
import processing.video.*;
import codeanticode.syphon.*;

SyphonServer server;

PGraphics canvas;

int cols;
int rows;
float[][] current;// = new float[cols][rows];
float[][] previous;// = new float[cols][rows];

float dampening = 0.99;
  
ArrayList<PVector> elements;

boolean print = false; // saveFrame()
boolean updateFrame = false;

boolean red; 
boolean green;
boolean blue;

BlobDetection theBlobDetection;

int numPixels;
int[] previousFrame;
Capture video;

int WIDTH = 640;
int HEIGHT = 360;

int CAMERA_INDEX = 3;

PImage diff_img;
PImage img;

// SOUND 
import supercollider.*;
import oscP5.*;

ArrayList <Synth> synths;

void setup() {
  size(640, 360, P2D);
  
  
  synths = new ArrayList<Synth>();
    
  for(int i = 0; i < 10; i++){
    Synth _synth;
    String name = "sine" + i;
    println("name",  name);
    _synth = new Synth(name);
    _synth.set("amp", 0.0);
    _synth.set("freqx", 80*i);
    _synth.set("freqy", 40*i);
    _synth.create();
    synths.add(_synth);
  }
  
  canvas = createGraphics(WIDTH, HEIGHT, P2D);
  
  server = new SyphonServer(this, "Processing Syphon");
  
  String[] cameras = Capture.list();
  
  elements = new ArrayList<PVector>();
  
  cols = WIDTH;
  rows = HEIGHT;
  
  current = new float[cols][rows];
  previous = new float[cols][rows];
    
  for (int i = 0; i < cameras.length; i++) {
      println(i, cameras[i]);
   }
  // This the default video input, see the GettingStartedCapture 
  // example if it creates an error
  video = new Capture(this, cameras[CAMERA_INDEX]);  
  
  println(video.width);
  
  // Start capturing the images from the camera
  video.start(); 
  
  img = new PImage(WIDTH/10, HEIGHT/10);
  diff_img = new PImage(WIDTH, HEIGHT);
  
  theBlobDetection = new BlobDetection(WIDTH/10, HEIGHT/10);
  theBlobDetection.setPosDiscrimination(true);
  theBlobDetection.setThreshold(0.2f); // will detect bright areas whose luminosity > 0.2f;
  
  numPixels = WIDTH * HEIGHT;
  // Create an array to store the previously captured frame
  previousFrame = new int[numPixels];
  updatePreviousFrame();
  loadPixels();
  background(0);    
}

void draw() { 
  background(0);     
  if (video.available()) {    
    draw_ripples();        
    if(updateFrame){
      updatePreviousFrame();
    }
    canvas.beginDraw();
    canvas.background(0, 0);  
    canvas.endDraw();
    // When using video to manipulate the screen, use video.available() and
    // video.read() inside the draw() method so that it's safe to draw to the screen       
    frameDiff();              
    //filter(BLUR);
    diff_img.updatePixels();
    image(diff_img,0,0,width,height);
    img.copy(diff_img, 0, 0, video.width, video.height, 
        0, 0, img.width, img.height);
    fastblur(img, 3);    
    
    img.loadPixels();
    theBlobDetection.computeBlobs(img.pixels);
    drawBlobsAndEdges(true,true);
        
    canvas.image( diff_img, 0, 0, width ,height);        
    
    draw_lines();
    
    image(canvas, 0, 0);
  }       
  //image(diff_img,0,0,width,height); 
  //server.sendScreen();
  server.sendImage(canvas);
}

void frameDiff(){
  video.read(); // Read the new frame from the camera
  video.loadPixels(); // Make its pixels[] array available
  diff_img.loadPixels();            
  for (int y = 0; y < HEIGHT; y++) { // For each pixel in the video frame...       
    for (int x = 0; x < WIDTH; x++) { // For each pixel in the video frame...
      int i = (y*WIDTH) + x;
      
      color currColor = video.pixels[i];
      color prevColor = previousFrame[i];    
      
      float [] diff;
      
      diff = new float[5];
      for(int j = 1; j < 5; j++){                                      
        color c = video.pixels[max(min(numPixels-1, i+(j-2)+(WIDTH*(j-2))), 0)];
        color p = previousFrame[max(min(numPixels-1, i+(j-2)+(WIDTH*(j-2))), 0)];    
        
        float r1 = c >> 16  & 0xFF;
        float g1 = c >> 8  & 0xFF; 
        float b1 = c & 0xFF; 
        
        float r2 = p >> 16  & 0xFF;
        float g2 = p >> 8  & 0xFF; 
        float b2 = p & 0xFF; 
                
        float r_diff = r1 - r2;
        float g_diff = g1 - g2;
        float b_diff = b1 - b2;

        //diff[j] = r_diff + g_diff + b_diff;  
        diff[j] = g_diff;
      }            
      boolean hasFound = true;
      for(int j = 1; j < 5; j++){
        if(hasFound){
          hasFound = diff[j] > abs(15);
        }
      }
            
      if(hasFound){
        diff_img.pixels[i] = currColor;
      } else {
        diff_img.pixels[i] = color(0, 0);
      }
      //pixels[i] = currColor;
      //previousFrame[i] = currColor;
    }    
  }      
}


void drawBlobsAndEdges(boolean drawBlobs, boolean drawEdges)
{
  for(int i = 0; i < synths.size(); i++){
      synths.get(i).set("amp", 0.0);
    }
  for(int i = 0; i < elements.size(); i ++ ) {
     elements.remove(i); 
  }
  int i = 0; // found blobs
  noFill();
  Blob b;
  EdgeVertex eA,eB;
  for (int n=0 ; n<theBlobDetection.getBlobNb() ; n++)
  {
    b=theBlobDetection.getBlob(n);
    if (b!=null)
    {      
      // Edges
      if (drawEdges)
      {        
        canvas.beginDraw();          
        strokeWeight(3);
        stroke(0,255,0);
        for (int m=0;m<b.getEdgeNb();m++)
        {
          eA = b.getEdgeVertexA(m);
          eB = b.getEdgeVertexB(m);
          if (eA !=null && eB !=null)
           
            canvas.stroke(0, 255, 0);
            canvas.line(
              eA.x*width, eA.y*height, 
              eB.x*width, eB.y*height
              );
            
        }
        canvas.endDraw();
      }

      // Blobs
      if (drawBlobs)
      {        
        strokeWeight(1);
        stroke(255,0,0);
        // rect( b.xMin*width,b.yMin*height,b.w*width,b.h*height);
          
        ellipseMode(CENTER);
        
        // fill(100);  // Set fill to gray                       
        fill(125, 0 , 255);
        float xCenter = b.xMin*width + b.w*width/2;
        float yCenter = b.yMin*height + b.h*height/2;
                   
        PVector pos = new PVector(xCenter, yCenter);
        
        previous[int(xCenter)][int(yCenter)] = 1000;
        
        //if(b.w*width > 10){
           elements.add(pos);
           ellipse(xCenter, yCenter, 10, 10); 
            synths.get(i).set("amp", 0.1);
            synths.get(i).set("freqx", 40 + ((xCenter-yCenter) * i ));
            synths.get(i).set("freqy", 40 + ((b.w*width)));     
            i++;
        //}                     
      }
    }
  }   
}

void draw_lines(){
  canvas.beginDraw();
  for(int i = 0; i < elements.size()-1; i++ ) {
     PVector pos = elements.get(i);
     PVector next_pos = elements.get(i+1);               
     canvas.strokeWeight(3);
     canvas.stroke(255, 0 ,0);
     canvas.line(pos.x, pos.y, next_pos.x, next_pos.y);     
  }  
  canvas.endDraw();
}

void updatePreviousFrame(){
  println("update ref frame!");
  if (video.available()) {
    for(int i = 0; i < synths.size(); i++){
      synths.get(i).set("amp", 0.0);
    }
    
    
    video.read(); // Read the new frame from the camera
    video.loadPixels(); // Make its pixels[] array available
      for (int i = 0; i < numPixels; i++) { // For each pixel in the video frame...
        color currColor = video.pixels[i];
        previousFrame[i] = currColor;
      }
      updateFrame = false;
   }
}

void mouseDragged() {
  //previous[mouseX][mouseY] = 1000;
}

void draw_ripples() {  
  canvas.loadPixels();
  for (int i = 1; i < cols-1; i++) {
    for (int j = 1; j < rows-1; j++) {
      current[i][j] = (
        previous[i-1][j] + 
        previous[i+1][j] +
        previous[i][j-1] + 
        previous[i][j+1]) / 2 -
        current[i][j];
      current[i][j] = current[i][j] * dampening;
      int index = i + j * cols;
      canvas.pixels[index] = color(current[i][j]);
    }
  }
  canvas.updatePixels();

  float[][] temp = previous;
  previous = current;
  current = temp;
}

void keyPressed() {
  if (key == 's') {
    if (print == false) { 
      print = true;
    } else if (print == true) {
      print = false;
    }
  }
  
  if(key == 'a'){
    updateFrame = true;
  }
  
  
  
 if(key =='r') {
   if(red){
     red = false;
   }else {
     red = true;
   }
 }
 if(key =='g') {
   if(green){
     green = false;
   }else {
     green = true;
   }
 }
 
 if(key =='r') {
   if(red){
     red = false;
   }else {
     red = true;
   }
 }
 if(key =='b') {
   if(blue){
     blue = false;
   }else {
     blue = true;
   }
 }
 if(key =='g') {
   if(green){
     green = false;
   }else {
     green = true;
   }
 }  
}

void exit()
{
    //synth2.free();
    for(int i = 0; i < synths.size(); i++){
      synths.get(i).free();
    }
    super.exit();
}