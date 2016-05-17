# MacLexa
![Alt text](http://i.imgur.com/BzSViXy.png "MacLexa System Tray Expanded")
## About the Project
I was debating on buying an Echo, but then I learned Amazon has an Alexa Voice Service SDK. So I decided to build an Alexa App which lives in the Mac System Tray and can be accessed at any time by pressing and holding the Option key when speaking commands. 

___

##Benefits of this app vs the Amazon Echo

1. You can do client side processing on the Audio (i.e: determine who is speaking, get sentiment or emotion analysis...etc)
2. It's much easier for demoing the Amazon skill you just created at a Hackathon
3. It's Free! ;)

---
##Getting Started

###Amazon Developer Account
1. Create an account at developer.amazon.com
2. Follow the [getting started guide](https://developer.amazon.com/appsandservices/solutions/alexa/alexa-voice-service/getting-started-with-the-alexa-voice-service) for Amazon Voice Service.
3. In the procedure keep track of your Application Type ID and Client ID. We will need those values later. 

###Install Dependencies
[Carthage](https://github.com/Carthage/Carthage) is used for dependancies. After cloning go into the root directory and run:

```
carthage bootstrap
```
Since this is Carthage, make sure to add the GCDframework for Mac OSX to the project after your done running the bootstrap command. 

###Enter Config Values
![Alt text](http://i.imgur.com/gjoth5j.png "MacLexa System Tray")
- Click on the MacLexa icon to show the Nib. 
- Enter in the Application Type ID and Client ID
- Register


###Begin!
![Alt text](http://i.imgur.com/D3aVC6j.png "MacLexa Recording in the System Tray")
- Press the Option Key to start recording, on first press it will see you dont have a token and open up a safari window for you to enter your amazon creds
- Hold and Press the option key while you're talking to Alexa. You will see a red record icon pop up become visible while you are speaking to alexa. 

---
email kunal@debug.io for questions
