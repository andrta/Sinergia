import oscP5.*;
import netP5.*;
import gab.opencv.*;
import KinectPV2.*;
import java.awt.Rectangle;
import java.util.Timer;
import java.util.TimerTask;


private final int MIN_TRANSPOSE = -48;
private final int MAX_TRANSPOSE = 20;


private final int PUREDATA_POSITIONS_PORT = 9001;
private final int PUREDATA_TRANSPOSE_PORT = 9002;
private final String PUREDATA_DESTINATION_IP= "192.168.0.102";
private final String PURRDATA_POSITIONS_ADDRESS_PATTERN = "/positions";
private final String PUREDATA_TRANSPOSE_ADDRESS_PATTERN = "/transpose";

private final int MADMAPPER_POSITIONS_PORT = 9999;
private final String MADMAPPER_DESTINATION_IP= "192.168.0.108";
private final String MADMAPPER_POSITIONS_ADDRESS_PATTERN = "/blobs";

private final long THIRTY_SECONDS_IN_MILLIS = 30000;

int CAMERA_WIDTH = 512;
int CAMERA_HEIGHT = 424;

int numPointsThreshold = 350; 
int threshold = 30; 
int maxD = 700; 
//int maxD = 2000; 
int minD = 10; 

KinectPV2 kinect;
OpenCV opencv;
ArrayList<Blob> blobs = new ArrayList<Blob>();
float polygonFactor = 1;
int blobCounter = 0;
int maxLife = 10;

OscP5 oscP5;
private NetAddress pureDataDestinationNetAddressPositions;
private NetAddress pureDataDestinationNetAddressTranspose;
private NetAddress madmapperDestinationNetAddress;

void setup() {
  size(512, 424, P3D);
  opencv = new OpenCV(this, CAMERA_WIDTH, CAMERA_HEIGHT);
  kinect = new KinectPV2(this);

  kinect.enableDepthImg(true);
  kinect.enableBodyTrackImg(true);
  kinect.enablePointCloud(true);
  kinect.init();
  //Ponemos las distancias maximas y minimas a las que detectamos
  kinect.setLowThresholdPC(minD);
  kinect.setHighThresholdPC(maxD);

  oscP5 = new OscP5(this, 7001);
  pureDataDestinationNetAddressPositions = new NetAddress(PUREDATA_DESTINATION_IP, PUREDATA_POSITIONS_PORT);
  pureDataDestinationNetAddressTranspose = new NetAddress(PUREDATA_DESTINATION_IP, PUREDATA_TRANSPOSE_PORT);
  madmapperDestinationNetAddress = new NetAddress(MADMAPPER_DESTINATION_IP, MADMAPPER_POSITIONS_PORT);

  new Timer().schedule(new SendTransposeValue(), 0, THIRTY_SECONDS_IN_MILLIS);
}

void draw() {
  background(0);

  opencv.loadImage(kinect.getPointCloudDepthImage());
  opencv.gray();
  opencv.threshold(threshold);
  image(opencv.getOutput(), 0, 0);

  ArrayList<Blob> currentBlobs = new ArrayList<Blob>();

  ArrayList<Contour> contours = opencv.findContours(false, false);
  if (contours.size() > 0) {
    for (Contour contour : contours) {
      Rectangle detectedBlob = contour.getBoundingBox();
      contour.setPolygonApproximationFactor(polygonFactor);
      if (contour.numPoints() > numPointsThreshold) {
        boolean found = false;
        for (Blob b : currentBlobs) {
          if (b.isNear(detectedBlob.x, detectedBlob.y)) {
            b.add(detectedBlob.x, detectedBlob.y, detectedBlob.width, detectedBlob.height, maxLife);
            found = true;
            break;
          }
        }
        if (!found) {
          Blob b = new Blob(currentBlobs.size(), detectedBlob.x, detectedBlob.y, detectedBlob.width, detectedBlob.height, maxLife);
          currentBlobs.add(b);
        }
      }
    }
  }

  for (int i = currentBlobs.size()-1; i >= 0; i--) {
    if (currentBlobs.get(i).size() < 500) {
      currentBlobs.remove(i);
    }
  }

  // There are no blobs!
  if (blobs.isEmpty() && currentBlobs.size() > 0) {
    println("Adding blobs!");
    for (Blob b : currentBlobs) {
      b.id = blobCounter;
      blobs.add(b);
      blobCounter++;
    }
  } else if (blobs.size() <= currentBlobs.size()) {
    // Match whatever blobs you can match
    for (Blob b : blobs) {
      float recordD = 1000;
      Blob matched = null;
      for (Blob cb : currentBlobs) {
        PVector centerB = b.getCenter();
        PVector centerCB = cb.getCenter();
        float d = PVector.dist(centerB, centerCB);
        if (d < recordD && !cb.taken) {
          recordD = d;
          matched = cb;
        }
      }
      matched.taken = true;
      b.become(matched);
    }

    // Whatever is leftover make new blobs
    for (Blob b : currentBlobs) {
      if (!b.taken) {
        b.id = blobCounter;
        blobs.add(b);
        blobCounter++;
      }
    }
  } else if (blobs.size() > currentBlobs.size()) {
    for (Blob b : blobs) {
      b.taken = false;
    }


    // Match whatever blobs you can match
    for (Blob cb : currentBlobs) {
      float recordD = 1000;
      Blob matched = null;
      for (Blob b : blobs) {
        PVector centerB = b.getCenter();
        PVector centerCB = cb.getCenter();
        float d = PVector.dist(centerB, centerCB);
        if (d < recordD && !b.taken) {
          recordD = d;
          matched = b;
        }
      }
      if (matched != null) {
        matched.taken = true;
        matched.become(cb);
      }
    }

    for (int i = blobs.size() - 1; i >= 0; i--) {
      Blob b = blobs.get(i);
      if (!b.taken) {
        if (b.checkLife()) {
          blobs.remove(i);
        }
      }
    }
  }

  for (Blob b : blobs) {
    b.show();
  }

  sendBlobListToMadmapper(blobs);
  sendBlobListToPureData(blobs);

  pushMatrix();
  translate(0, 0);
  textAlign(LEFT);
  noStroke();
  fill(0);
  rect(0, 0, 130, 100);
  fill(0, 255, 0);
  textSize(12);
  text("fps: "+frameRate, 20, 20);
  text("threshold: "+threshold, 20, 40);
  text("minD: "+minD, 20, 60);
  text("maxD: "+maxD, 20, 80);
  text("total blobs: "+blobs.size(), 20, 100);
  popMatrix();
}

int multiplier = 1;
int total = -47 ;
private void sendTransposeValueToPureData(ArrayList<Blob> blobList) {
  if (blobList != null && blobList.size() > 0) {
    Blob lastBlob = blobList.get(blobList.size() -1);
    if (lastBlob != null) {
      if (total <= MIN_TRANSPOSE || total >= MAX_TRANSPOSE) multiplier *= -1;
      
      total += multiplier;
      final OscMessage message = new OscMessage(PUREDATA_TRANSPOSE_ADDRESS_PATTERN);
      message.add(total);
      oscP5.send(message, pureDataDestinationNetAddressTranspose);
    }
  }
}

private void sendBlobListToMadmapper(ArrayList<Blob> blobList) {
  final OscMessage message = new OscMessage(MADMAPPER_POSITIONS_ADDRESS_PATTERN);
  message.add(blobList.size());
  for (Blob b : blobList) {
    message.add(b.id);
    PVector center = b.getCenter();
    message.add(map(center.x, 0, CAMERA_WIDTH, 0, 1));
    message.add(map(center.y, 0, CAMERA_HEIGHT, 0, 1));
    message.add(map(b.w, 0, CAMERA_WIDTH, 0, 1));
    message.add(map(b.h, 0, CAMERA_HEIGHT, 0, 1));
  }
  oscP5.send(message, madmapperDestinationNetAddress);
}

private void sendBlobListToPureData(ArrayList<Blob> blobList) {
  final OscMessage message = new OscMessage(PURRDATA_POSITIONS_ADDRESS_PATTERN);
  message.add(blobList.size());
  for (Blob b : blobList) {
    message.add(b.id);
    PVector center = b.getCenter();
    message.add(map(center.x, 0, CAMERA_WIDTH, 0, 1));
    message.add(map(center.y, 0, CAMERA_HEIGHT, 0, 1));
  }
  oscP5.send(message, pureDataDestinationNetAddressPositions);
}

float distSq(float x1, float y1, float x2, float y2) {
  float d = (x2-x1)*(x2-x1) + (y2-y1)*(y2-y1);
  return d;
}

class SendTransposeValue extends TimerTask {
  public void run() {
    sendTransposeValueToPureData(blobs);
  }
}
