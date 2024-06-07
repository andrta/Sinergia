 import java.util.UUID;

class Blob {
  private int id = 0;
  private float x;
  private float y;
  private float w;
  private float h;
  private int lifeSpan;
  private boolean taken = false;

  Blob(int id, float x, float y, float w, float h, int lifeSpan) {
    this.id  = id;
    this.x = x;
    this.y = y;
    this.w = w;
    this.h = h;
    this.lifeSpan = lifeSpan;
  }

  boolean checkLife() {
    lifeSpan--;
    if (lifeSpan < 0) {
      return true;
    } else {
      return false;
    }
  }
  
  boolean isNear(float px, float py) {
    float cx = max(x + w / 2, x);
    float cy = max(y + h / 2, y);
    float d = distSq(cx, cy, px, py);
    if (d < threshold*threshold) {
      return true;
    } else {
      return false;
    }
  }

  void show() {
    noFill();
    stroke(0, 255, 0);
    strokeWeight(3);

    pushMatrix();
    translate(x, y);
    ellipseMode(CENTER);
    ellipse(0 + w / 2, 0 + h / 2, 10, 10);
    
    strokeWeight(2);
    rectMode(CORNER);
    rect(0, 0, w, h);

    textAlign(CENTER);
    textSize(32);
    fill(0);
    text(id, 0 + w / 2, 0 + h / 2);
    //textSize(16);
    //println("lifespan: "+lifespan);
    //text(lifespan, 0, 0);
    popMatrix();
  }

 void become(Blob other) {
    x = other.x;
    y = other.y;
    w = other.w;
    h = other.h;
    lifeSpan = other.lifeSpan;
  }

 PVector getCenter() {
    float px = w * 0.5 + x;
    float py = h * 0.5 + y;    
    return new PVector(px, py); 
  }

  void add(float x, float y, float w, float h, int lifeSpan) {
    this.x = x;
    this.y = y;
    this.w = w;
    this.h = h;
    this.lifeSpan = lifeSpan;
  }

  float size() {
    return w * h;
  }
}
