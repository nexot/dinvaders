//###################################################
// File: dinvaders.d
// Created: 2015-02-23 07:55:59
// Modified: 2015-02-27 08:50:16
//
// See LICENSE file for license and copyright details
//###################################################


import std.stdio;

import Dgame.Window;
import Dgame.Graphic;
import Dgame.System.StopWatch;
import Dgame.System.Keyboard;
import Dgame.Math.Rect;
import Dgame.Math;

// globals are cool!
immutable int windowWidth = 1024, windowHeight = 768;
immutable int FPS = 30;
immutable ubyte TICKS_PER_FRAME = 1000 / FPS; 

StopWatch timer;

//bool gameOn = false;
//bool running = false;
enum State {PENDING, INPROGRESS, WIN, LOST, ABORT, QUIT};
auto running = State.PENDING;

// Manage the player
struct Player {
    static immutable int width = 77, height = 80;    
    static immutable string image = "./player.png";
    static immutable int startX =windowWidth / 2-Player.width/2, startY = 650;
    Texture img;//get it from local create context
    Sprite player;

    int moveDir = 0;
    void create()
    {      
        img = Texture(Surface(Player.image));        
        player = new Sprite(img);
        player.setPosition(Player.startX, Player.startY);

       
    }
    // Called once per frame
    void update(ref Window wnd)
    {
        if(player.getPosition.x < 5 && moveDir < 0) {
            moveDir = 0;
        } else if(player.getPosition.x > windowWidth-Player.width-5 && moveDir > 0) {
            moveDir = 0;
        }
        player.move(moveDir, 0);

        //some fansy movements, smoother and need more moveDir
/*        if (moveDir > 0) {
            player.move(1, 0);
            moveDir -= 1;
        } else if (moveDir < 0) {
            player.move(-1,0);
            moveDir += 1;
        }
 */       
        wnd.draw(player);    
        
    }
    void fireBullet(ref Bullet bullet)
    {
        bullet.sprite.setPosition(player.getPosition.x + Player.width / 2, player.getPosition.y);
        
        bullet.moveDir = -10;
        bullet.active = true;
    }
}
// Manage the state of the alien pack
// and shuffle on update.
struct Aliens {
    static immutable int width = 76, height = 80;
    static immutable string image = "./alien.png";
    static immutable int numRows = 4;
    static immutable int numCols = 7;
    static immutable int offsetX = Aliens.width + 5; // Some spacing for the pack
    static immutable int offsetY = Aliens.height + 5;
    static immutable int moveX = 10;

    Spritesheet[numRows*numCols] aliens;
    bool[numRows*numCols] alienOn;
    int alienCount = numRows*numCols;
    StopWatch timeout;
    int packX = 50, packY = 50; // The top-left of the alien pack
    int packDir = 1;
    // When frameCount reaches 0 we update. The update latch specified
    // the number of frames before an update and changes to increase
    // the speed.
    int updateLatch = 250;
    
    Texture img;
    
    /// Create the aliens.
    void create()
    {
        timeout = StopWatch.init;
        img =  Texture(Surface(Aliens.image));
        int idx = 0;
        foreach(ii; 0..numRows) {
            foreach(jj; 0..numCols) {
                aliens[idx]= new Spritesheet(img, Rect(0, 0, Aliens.width, Aliens.height));
                int x = jj * Aliens.offsetX + 50;
                int y = ii * Aliens.offsetY + 50;
                aliens[idx].setPosition(x, y);
                alienOn[idx] = true;
                ++idx;
            }
        }
    }
    // Called every frame
    void update(ref Window wnd)
    {
        bool slide = false;
        //if(gameOn && timeout.getElapsedTicks() > updateLatch) {
        if(running==State.INPROGRESS && timeout.getElapsedTicks() > updateLatch) {
            // Shuffle along...
            packX += moveX*packDir;

            // Reached the end of the scan, start a new row and
            // increase the speed of these puppies.
            if(packX > 450 || packX < 50) {
                packDir *= -1;
                packY += (Aliens.height + 5);
                writeln(packY);
                //if(packY > 400) { // well, game over           
                if (packY > windowHeight) { /// puppies go down, reset them
                    packY = 0;
                }
                updateLatch /= 2;
            }
            slide =true;
            timeout.reset();
        }
        int idx = 0;
        foreach(y; 0..Aliens.numRows) {
            foreach(x; 0..Aliens.numCols) {
                if(alienOn[idx]) {
                    if(slide) {
                        aliens[idx].slideTextureRect();
                        aliens[idx].setPosition( x*Aliens.offsetX + packX, y*Aliens.offsetY + packY);
                    }
                    wnd.draw(aliens[idx]);
                }
                ++idx;
            }
        }
    }
    // Called when an alien is destroyed. Turns off the alien sprite and
    // turns on the corresponding explosion (have none).
    void destroy(int idx)
    {
        alienOn[idx] = false;
        writeln("Aliens left:", --alienCount); // just curious
        if (alienCount<=0) running = State.WIN;
    }
    // Check for collisions between aliens-player and aliens-bullet
    void checkCollisions(ref Bullet[2] bullets, ref Player player)
    {
        foreach(int idx, alien; aliens) {
            if(alienOn[idx]) {
                if(bullets[0].active && alien.getClipRect.intersects(bullets[0].sprite.getClipRect, null)) {
                    destroy(idx);
                    bullets[0].active = false;
                }
                if(bullets[1].active && alien.getClipRect.intersects(bullets[1].sprite.getClipRect, null)) {
                    destroy(idx);
                    bullets[1].active = false;
                }
                if(alien.getClipRect.intersects(player.player.getClipRect, null)) {// Oops, game over!
                    //gameOn = false;
                    running = State.LOST;
                }
            }
        }
    }

}
// Manage bullets
struct Bullet {
    static immutable int width = 17, height = 40;
    static immutable string image = "./player_bullet.png";
    Texture img;
    Sprite sprite;
    int moveDir = 0;
    bool active = false;
    void create()
    {
        img =  Texture(Surface(Bullet.image));
        sprite = new Sprite(img);
    }
    void update(ref Window wnd)
    {
        if(active) {
            sprite.move(0, moveDir);
            wnd.draw(sprite);
            if(sprite.getPosition.y < 5) {
                active = false;
            }
        }
    }
}
// Background space
struct BackSpace {
    static immutable int sizeSol = 25;
    static immutable int startXSol = 180, startYSol = 380;
    
    StopWatch timeout;
    
    Sol sun1;    
    Sol sun2;
    
        void create()
        {
            sun1.create(25, 180, 380, -1);
            sun2.create(50, 800, 1500, -2);
        }
        void update(ref Window wnd)
        {
            sun1.update(wnd);
            sun2.update(wnd);
        }        
    // Solar
    struct Sol {  
        int movDir;
        
        Shape circle;
        
        void create(in int size,in int startX, in int startY, in int shift)
        {
            movDir = shift;
            
            circle = new Shape(size, Vector2f(startX, startY));
            circle.setColor(Color4b.Green);         
        }
        void update(ref Window wnd)
        {               
            circle.move(0,movDir);

            wnd.draw(circle); ///love that circle. looks like some green star     
        }
    }
}
// Kickstart
void main()
{
    Window wnd =  Window(windowWidth, windowHeight, "D-Invaders");
    wnd.setVerticalSync(Window.VerticalSync.Disable);

    StopWatch FPSclock;///  FPS control  
    
    auto aliens = Aliens();
    auto player = Player();
    auto background = BackSpace();
    Bullet[2] bullets;
    
    // Setup our aliens.   
    void level0() {
        wnd.setClearColor(Color4b.Black); /// Default would be Color.White
        wnd.clear(); /// Clear the buffer and fill it with the clear Color
        wnd.display();

        aliens = Aliens();
        player = Player();
        background = BackSpace();
        bullets[0] = Bullet();
        bullets[1] = Bullet();
        
        aliens.create();
        player.create();
        background.create();
        
        bullets[0].create();
        bullets[1].create();
        running = State.INPROGRESS;   
        
        player.moveDir = 0;
    }
    
    //gameOn = true;
    level0();
    // Start the event loop
    Event event;
    while(running!=State.QUIT) { 
        switch (running) {
            case State.INPROGRESS : {    
            //if(gameOn) {
                if (FPSclock.getElapsedTicks() >= TICKS_PER_FRAME) {
                    wnd.clear();
                    while(wnd.poll(&event)) {
                        switch(event.type) {
                            case Event.Type.Quit : {                            
                                running = State.QUIT;// quit event loop
                                break;
                            }
                            case Event.Type.KeyDown : {  
                                switch(event.keyboard.key) {
                                    case Keyboard.Key.Esc: {
                                        wnd.push(Event.Type.Quit);
                                        break;
                                    }
                                    case Keyboard.Key.Left: {
                                        player.moveDir = -5;
                                        break;
                                    }
                                    case Keyboard.Key.Right: {
                                        player.moveDir = 5;
                                        break;
                                    }
                                    case Keyboard.Key.L: {
                                        running = State.LOST;
                                        break;
                                    }
                                    case Keyboard.Key.W: {
                                        running = State.WIN;
                                        break;
                                    }                                    
                                    case Keyboard.Key.Space: {
                                        // Do we have a bullet to fire?
                                        if(!bullets[0].active) {
                                            player.fireBullet(bullets[0]);                                    
                                        } else if(!bullets[1].active) {
                                            player.fireBullet(bullets[1]);                                    
                                        }
                                        break;
                                    }
                                    default :
                                        break;
                                }
                                default :
                                    break;
                            }
                        }
                    }
                    // Update the aliens
                    background.update(wnd);
                    aliens.update(wnd);
                    player.update( wnd);
                    if(bullets[0].active) {
                        bullets[0].update(wnd); // these only draw if active
                    }
                    if(bullets[1].active) {
                        bullets[1].update(wnd);
                   }
                    aliens.checkCollisions(bullets, player);
                    wnd.display();
                    FPSclock.reset();     
                } 
                break;        
            }    
            //} else { // Too bad, game over
            case State.LOST : {
                wnd.setClearColor(Color4b.Red);
                wnd.clear();
                wnd.display();
                StopWatch.wait(1000);
                //running = State.QUIT;// quit event loop
                running = State.PENDING;
                break;
            }
            case State.WIN : {
                wnd.setClearColor(Color4b.Green);
                wnd.clear();
                wnd.display();
                StopWatch.wait(1000);
                running = State.PENDING;                
                break;
            }               
            case State.PENDING : {
                level0();                
                break;
            }            
            default : {
                break;
            }
        }
    }    
}
