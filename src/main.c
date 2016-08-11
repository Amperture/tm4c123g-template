#include "main.h"

#include <stdbool.h>
#include "driverlib/gpio.h"
#include "driverlib/pin_map.h"
#include "driverlib/sysctl.h"
#include "inc/hw_gpio.h"
#include "inc/hw_types.h"
#include "inc/hw_memmap.h"

void delay(){
    //delay for 1ms
    SysCtlDelay( (SysCtlClockGet()/(3*1000)));
}

void hwInit(){

    //Clock Init
    SysCtlClockSet(SYSCTL_SYSDIV_1 | 
           SYSCTL_USE_OSC |   
           SYSCTL_OSC_MAIN | 
           SYSCTL_XTAL_16MHZ);

    //GPIOF Init
    SysCtlPeripheralEnable(SYSCTL_PERIPH_GPIOF);

    GPIOPinTypeGPIOOutput(GPIO_PORTF_BASE, GPIO_PIN_1);

}


int main(void){
    hwInit();
    int i = 0;

    while(1){
        for (i=0; i < 100; i++){
            delay(); 
        }

        GPIOPinWrite(GPIO_PORTF_BASE,
                GPIO_PIN_1,
                GPIO_PIN_1);

        for (i=0; i < 100; i++){
            delay(); 
        }

        GPIOPinWrite(GPIO_PORTF_BASE,
                GPIO_PIN_1,
                0);
    }

}
