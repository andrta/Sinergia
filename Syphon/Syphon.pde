import codeanticode.syphon.*;
import oscP5.*;
import netP5.*;
import java.util.*;

SyphonServer syphonServer;
ArrayList<Blob> blobs = new ArrayList();
OscP5 oscP5;
PGraphics canvas;
boolean isDrawing = false;

final int SCREEN_WIDTH = 512;
final int SCREEN_HEIGHT = 424;

void setup() {
  size(512, 424, P3D);
  syphonServer = new SyphonServer (this, "Processing Syphon") ;
  oscP5 = new OscP5(this, 9999);
  canvas = createGraphics (SCREEN_WIDTH, SCREEN_HEIGHT, P3D) ;
}

void draw() {
  isDrawing = true;
  canvas.beginDraw();
  canvas.background(0);
  for (Blob blob : blobs) {
    showBlob(blob);
  }
  canvas.endDraw();
  isDrawing = false;
  syphonServer.sendImage(canvas);
  image(canvas, 0, 0);
}

void oscEvent(OscMessage theOscMessage) {
  if (!isDrawing) {
    blobs = new ArrayList<Blob>();
    if (theOscMessage.checkAddrPattern("/blobs")) {
      println(theOscMessage);
      int blobListSize = theOscMessage.get(0).intValue();
      int attributeCounter = 1;
      for (int i = 0; i < blobListSize; i++) {
        blobs.add(new Blob(
          theOscMessage.get(attributeCounter++).intValue(),
          map(theOscMessage.get(attributeCounter++).floatValue(), 0, 1, 0, SCREEN_WIDTH),
          map(theOscMessage.get(attributeCounter++).floatValue(), 0, 1, SCREEN_HEIGHT, 0),
          map(theOscMessage.get(attributeCounter++).floatValue(), 0, 1, 0, SCREEN_WIDTH),
          map(theOscMessage.get(attributeCounter++).floatValue(), 0, 1, 0, SCREEN_HEIGHT))
          );
      }
    }
  }
}

void showBlob(final Blob blob) {
  canvas.pushMatrix();
  canvas.translate(blob.x, blob.y);
  canvas.ellipseMode(CENTER);
  canvas.fill(255);
  canvas.ellipse(0, 0, blob.w / 1.5, blob.h / 1.5);
  canvas.popMatrix();
}
