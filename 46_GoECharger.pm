###############################################################################
# 
#  (c) 2020 Copyright Lutz R., Fhem forum user LR66 (LR66 at gmx dot de)
#  All rights reserved
#
#  This script is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  any later version.
#
#  The GNU General Public License can be found at
#  http://www.gnu.org/copyleft/gpl.html.
#  A copy is found in the textfile GPL.txt and important notices to the license
#  from the author is found in LICENSE.txt distributed with these scripts.
#
#  This script is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
###############################################################################
##
##
# based at and tested with goE-Charger firmware 033 and API 1.5
# and mail 14.04.20 from go-e (thanks go-e)


package main;


my $missingModul = "";

use strict;
use warnings;

use HttpUtils;
eval "use JSON;1" or $missingModul .= "JSON ";


my $version = "0.1.5";

my %goevar;
my $reading_keys_json_allkeys='';
my $reading_keys_json_default='';
my $reading_keys_json_minimal='';
my $reading_keys_json;
my $maxamp=16;


my $icodef='disabled.*:ev-station@darkgrey not_allowed.*:ev-station@white ready_no_car.*:ev-station@blue charging.*:ev-station@darkorange waiting_for_car.*:ev-station@pink finished.*:ev-station@lime error.*:ev-station@red .*:ev-station@yellow';

    %goevar         =   (   
                        version =>  'version',          #R# JSON, "B": normal, "C":  wenn Verschl. aktiviert 
                        rbc     =>  'reboot_counter',   #R# Anzahl Boot, .  
                        rbt     =>  'reboot_timer',     #R# msec seit letzten Bootvorgang, mit Ende-zu-Ende Verschl. 
                                                        # ges., Überlauf 49d mit Erhöh. rbc
                        car     =>  'car_state',        # R#Status PWM 1 = bereit - kein Fz., 2 = Fz. lädt, 
                                                        # 3 = Warte auf Fz., 4 = Ladung Ende - Fz. noch da 
                        amp     =>  'amp_current',      #W# Ampere Wert für PWM Sign. in ganzen Ampere von 6-32A 
                        err     =>  'error',            #R# error: 1=RCCB (Fi), 3=PHASE, 8=NO_GROUND (Erdungserk.),
                                                        # 10= default INTERNAL (sonstiges) 
                        ast     =>  'access_control_state', #W# Zugangskontrolle,0=Offen,1=RFID/App nötig,
                                                        # 2= Strompr./ automatisch 
                        alw     =>  'allow_charging',   #W# PWM Signal darf anliegen,0 = nein, 1 = ja 
                        stp     =>  'stop_kWh_state_useless',   #W# autom. Abschaltung,0 = deaktiviert, 2 = nach kWh abschalten
                                                        # NICHT verwendet, dwo setzen reicht (0 deaktiviert)
                        cbl     =>  'amp_max_cable',    #R# Typ2 Kabel Ampere codierung,13-32 (0 = kein Kabel) 
                        pha     =>  'phases_available', #R# Phasen vor und nach dem Schütz, binary 0b00ABCDEF 
                                                        # 0b00001000: Phase 1 vorh., 0b00111000: Phase1-3 vorh.
                                                        # A... phase 3, vor dem Schütz 
                                                        # B... phase 2 vor dem Schütz 
                                                        # C... phase 1 vor dem Schütz 
                                                        # D... phase 3 nach dem Schütz 
                                                        # E... phase 2 nach dem Schütz 
                                                        # F... phase 1 nach dem Schütz  
                        tmp     =>  'temperature',      #R# Temperatur des Controllers in °C 
                        dws     =>  'kWh_charged_last', #R# Geladene Energiemenge in Deka-Watt-Sekunden,
                                                        # 100’000 = 1’000’000 Ws (=277Wh = 0,277kWh) 
                        dwo     =>  'stop_at_num_kWh',  #W# Abschaltwert in 0.1kWh wenn stp==2, für dws Parameter, 
                                                        # Beispiel: 105 für 10,5kWh 
                                                        # Ladebox-Logik:  if(dwo!=0 && dws/36000>=dwo)alw=0 
                        adi     =>  'amp_max16A_adapter',#R# Ladebox ist mit Adapter,0 = keiner, 1 = 16A_ADAPTER 
                        uby     =>  'unlocked_by_card',     #R# Nummer der RFID Karte, die Ladevorgang freigeschalten hat 
                        eto     =>  'kWh_charged_total',    #R# Gesamt geladene Energiemenge in 0.1kWh (130 = 13kWh) 
                        wst     =>  'wifi_state',       #R# WLAN Verbindungsstatus 3=verbunden, default=nicht verbunden 
                        nrg     =>  'energy_sensors',   #R# array[15]  Array mit Werten des Strom- und Spannungssensors 
                                                        # nrg[0]: Spannung auf L1 in Volt 
                                                        # nrg[1]: Spannung auf L2 in Volt 
                                                        # nrg[2]: Spannung auf L3 in Volt 
                                                        # nrg[3]: Spannung auf N in Volt 
                                                        # nrg[4]: Ampere auf L1 in 0.1A (123 entspricht 12,3A) 
                                                        # nrg[5]: Ampere auf L2 in 0.1A 
                                                        # nrg[6]: Ampere auf L3 in 0.1A 
                                                        # nrg[7]: Leistung auf L1 in 0.1kW (36 entspricht 3,6kW) 
                                                        # nrg[8]: Leistung auf L2 in 0.1kW 
                                                        # nrg[9]: Leistung auf L3 in 0.1kW 
                                                        # nrg[10]: Leistung auf N in 0.1kW 
                                                        # nrg[11]: Leistung gesamt  in 0.01kW (360 entspricht 3,6kW) 
                                                        # nrg[12]: Leistungsfaktor auf L1 in % 
                                                        # nrg[13]: Leistungsfaktor auf L2 in % 
                                                        # nrg[14]: Leistungsfaktor auf L3 in % 
                                                        # nrg[15]: Leistungsfaktor auf N in % 
 
                                                        # App Logik:: 
                                                        # if(Math.floor(pha/8) ==1 && 
                                                        #  parseInt(nrg[3])>parseInt(nrg[0])){ 
                                                        #     nrg[0]=nrg[3] 
                                                        #     nrg[7]=nrg[10] 
                                                        #     nrg[12]=nrg[15] 
                                                        # } 
                        fwv     =>  'firmware',         #R# String  Firmware Version Beispiel: "020-rc1" 
                        sse     =>  'serial_nr',        #R# Seriennummer als %06d formatierte Zahl, Beispiel: "000001" 
                        wss     =>  'wlan_ssid',        #W# WLAN SSID Beispiel: "Mein Heimnetzwerk" 
                        wke     =>  'wlan_key',         #W# WLAN Key Beispiel: "********" für fwv oder alt "passwort"
                        wen     =>  'wifi_enabled',     #W# WLAN aktiviert 0 = deaktiviert, 1 = aktiviert 
                        tof     =>  'gmt_time_offset',      #W# Zeitzone in h f. int. Batt.-Uhr +100 (101 = GMT+1) 
                        tds     =>  'daylights_time_offset',    #W# Daylight saving time offset (Sommerzeit) in h, 
                                                                # Beispiel: 1 für Mitteleuropa 
                        lbr     =>  'led_brightness',       #W# LED Helligkeit von 0-255 (0 = aus, 255 = max) 
                        aho     =>  'byPrice_min_hrs_charge',   #W# Min. Anzahl h in der mit "Strompreis - automatisch"         
                                                                # geladen werden muss 
                                                                # Beispiel: 2 ("Auto ist nach 2 Stunden voll genug") 
                        afi     =>  'byPrice_till_oclock_charge',       #W# Stunde (Uhrzeit) in der mit "Strompreis - automatisch" die 
                                                        # Ladung mindestens aho Stunden gedauert haben muss.
                                                        # Beispiel: 7 ("Fertig bis 7:00, also davor mindestens 2 Stunden geladen") 
                        azo     =>  'aWattar_zone',     #W# Awattar Preiszone 0: Österreich 1: Deutschland 
                        ama     =>  'amp_max_wallbox',          #W#Absolute max. Amp. (physisches Anlagen-Limit, z.b. 20) 
                        al1     =>  'amp_lvl01',        #W# Ampere Level 1 f. Knopf, 6-32 (A), 0= überspringen 
                        al2     =>  'amp_lvl02',        #W# Ampere Level 2 für Druckknopf am Gerät: 0 oder > al1 
                        al3     =>  'amp_lvl03',        #W# Ampere Level 3 für Druckknopf am Gerät: 0 oder > al2 
                        al4     =>  'amp_lvl04',        #W# Ampere Level 4 für Druckknopf am Gerät: 0 oder > al3
                        al5     =>  'amp_lvl05',        #W# Ampere Level 5 für Druckknopf am Gerät: 0 oder > al4 
                        cid     =>  'led_color_idle',   #W# Color idle: Farbe Standby kein Auto, def. 65535 (blau/grün) 
                        cch     =>  'led_color_chg',    #W# Color charging: Farbe für Laden, def. 255 (blau) 
                        cfi     =>  'led_color_fin',    #W# Color idle: Farbe Laden beendet,def. 65280(grün) 
                        lse     =>  'led_save_energy',  #W# LED nach 10 Sekunden abschalten ja = 1, nein = 0
                                                        # funktioniert so nicht, r2x= nutzen !
                        ust     =>  'cable_lock_state_at_box', #W# Kabelverriegelung: immer = 0, nur Laden =1
                                                        # 2: Kabel immer verriegelt lassen 
                        wak     =>  'ap_password',      #W# WLAN Hotspot Password Beispiel: "abdef0123456" 
                        r1x     =>  'wifi_flags',       #W# Flags 0b1: HTTP Api im WLAN akt. (0: nein, 1:ja) 0b10: 
                                                        # Ende-zu-Ende Verschl. akt. (0: nein, 1:ja) 
                        dto     =>  'byPrice_remain_hrs_start_charge',  #W# Restzeit in ms verbleibend auf Aktiv. durch Strompreise 
                                                        # App-logik:  
                                                        # if(json.car==1)message = "Zuerst Auto anstecken" 
                                                        # else message = "Restzeit:  … " 
                        nmo     =>  'norway_mode',      #W# Erdungserk. aktiv= 0, Norway Mode (nurIt-Netze) = deakt = 1 
                        eca     =>  'energy_card01',    #R#  Geladene Energiemenge pro RFID Karte von 1-10
                        ecr     =>  'energy_card02',        # Beispiel: eca==1400: 140kWh auf Karte 1 geladen
                        ecd     =>  'energy_card03',    # Beispiel: ec7==1400: 140kWh auf Karte 7 geladen
                        ec4     =>  'energy_card04',    # Beispiel: ec1==1400: 140kWh auf Karte 10 geladen
                        ec5     =>  'energy_card05', 
                        ec6     =>  'energy_card06', 
                        ec7     =>  'energy_card07', 
                        ec8     =>  'energy_card08', 
                        ec9     =>  'energy_card09', 
                        ec1     =>  'energy_card10', 
                        rca     =>  'id_card01',        #R# String  RFID Karte ID von 1-10 als String
                        rcr     =>  'id_card02', 
                        rcd     =>  'id_card03', 
                        rc4     =>  'id_card04', 
                        rc5     =>  'id_card05', 
                        rc6     =>  'id_card06', 
                        rc7     =>  'id_card07', 
                        rc8     =>  'id_card08', 
                        rc9     =>  'id_card09', 
                        rc1     =>  'id_card10', 
                        rna     =>  'name_card01',      #W# String  RFID Karte Name von 1-10, Maximallänge: 10 Zeichen
                        rnm     =>  'name_card02', 
                        rne     =>  'name_card03', 
                        rn4     =>  'name_card04', 
                        rn5     =>  'name_card05', 
                        rn6     =>  'name_card06', 
                        rn7     =>  'name_card07', 
                        rn8     =>  'name_card08', 
                        rn9     =>  'name_card09', 
                        rn1     =>  'name_card10', 
                        tme     =>  'clock_time',       #R# String  Akt. Uhrzeit, formatiert als ddmmyyhhmm 
                        sch     =>  'schedule',         #R# String  Scheduler einstellungen (base64 encodiert) 
                                                        # Funktionen zum encodieren und decodieren gibt es hier: 
                                                        # https://gist.github.com/peterpoetzi/6cd2fad2a915a2498776912c5a
                                                        # a137a8 
                                                        # Die Einstellungen können so gesetzt werden: 
                                                        # r21=Math.floor(encode(1)) 
                                                        # r31=Math.floor(encode(2)) 
                                                        # r41=Math.floor(encode(3)) 
                                                        # Ein direktes Setzen von sch= wird nicht unterstützt 
                        sdp     =>  'sched_dbl_press',  #R#  Scheduler double press: Aktiviert Ladung nach 
                                                        # doppeltem Drücken des Button, wenn die Ladung
                                                        # gerade durch den Scheduler unterbrochen wurde 0: Funktion deakt. 1: Ladung sofort erlauben 
                        upd     =>  'update_available', #(R)# Update avail. (nur über go-e Server),0 = nein, 1 = ja
                        cdi     =>  'cloud_disabled',   #W# Cloud disabled 0: cloud enabled 1: cloud disabled 
                        loe     =>  'cloud_mgmt',       #W# Lastmanagement enabled 0=deakt., 1= über Cloud akt. 
                        lot     =>  'load_mgmt_grpamp',  #W# Lastmanagement Gruppe Total Ampere 
                        lom     =>  'load_mgmt_minamp', #W# Lastmanagement minimale Amperezahl 
                        lop     =>  'load_mgmt_prio',   #W# Lastmanagement Priorität 
                        log     =>  'load_mgmt_grp',    #W# Lastmanagement Gruppen ID 
                        lon     =>  'load_mgmt_num',    #W# Lastmanagement: erw. Anz. Ladestationen (nicht unterstützt) 
                        lof     =>  'load_mgmt_fallbckamp', #W# Lastmanagement Fallback Amperezahl 
                        loa     =>  'load_mgmt_curramp',    #W# Lastmanagement Ampere (akt. erlaubter Ladestrom),
                                                            # vom Lastmanagement autom. gesteuert 
                        lch     =>  'load_mgmt_sec',    #W# Lastmanagement: Sekunden seit letzten Stromfluss bei noch 
                                                        # angestecktem Auto (0 wenn Ladevorgang) 
                        mce     =>  'mqtt_enabled',     #W# Verbindung mit eigenen MQTT Server herstellen 
                                                        # 0: Funktion deaktiviert 1: Funktion aktiviert 
                        mcs     =>  'mqtt_srv',         #W# String(63) MQTT custom Server, Hostname ohne 
                                                        # Protokollangabe (z.B. test.mosquitto.org) 
                        mcp     =>  'mqtt_port',        #W# MQTT custom Port z.B. 1883
                        mcu     =>  'mqtt_user',        #W# String(16) MQTT custom Username 
                        mck     =>  'mqtt_key',         #W# String(16) MQTT custom key,Für MQTT Authentifizierung 
                        mcc     =>  'mqtt_rdy',         #W# MQTT custom connected 0 = nicht verbunden 1 = verbunden
                        amt     =>  'amp_limit_by_temp',# max Strom limitiert durch Temp im Charger
                        tma     =>  'curr_sense_Typ2',      # Array 0,1,2,3,4 Stromsensoren Typ2
                        txi     =>  'transmit_interface',       # unknown
                    );              
# lesbare Parameter: siehe oben Kommentarstart mit #R#
# Lesen: Method  GET (liefert JSON)
# Beispiel: http://192.168.4.1/status 

# Setzbare Parameter: siehe oben Kommentarstart #W# 
# Setzen: Method  Payload, SET,  [param]=[value] 
# Beispiel:  http://192.168.4.1/mqtt?payload=amp=16
   
$reading_keys_json_allkeys= join(' ', keys(%goevar));
$reading_keys_json_default='afi adi aho alw ama amp amt ast azo car cbl cch cfi cid dto dwo dws err eto lbr lse tmp ust pha wak';
$reading_keys_json_minimal='alw amp ast car dws err eto ust';
$reading_keys_json=$reading_keys_json_default;



# Declare functions
sub GoECharger_Attr(@);
sub GoECharger_Define($$);
sub GoECharger_Initialize($);
sub GoECharger_Get($@);
sub GoECharger_Notify($$);
sub GoECharger_GetData($);
sub GoECharger_Undef($$);
sub GoECharger_ResponseProcessing($$$);
sub GoECharger_ErrorHandling($$$);
sub GoECharger_WriteReadings($$$);
sub GoECharger_Timer_GetData($);

my %paths = (   'status'    => '/status'
            );


sub GoECharger_Initialize($) {

    my ($hash) = @_;
    
    # Consumer
    $hash->{GetFn}      = "GoECharger_Get";
    $hash->{SetFn}      = "GoECharger_Set";
    $hash->{DefFn}      = "GoECharger_Define";
    $hash->{UndefFn}    = "GoECharger_Undef";
    $hash->{NotifyFn}   = "GoECharger_Notify";
    
    $hash->{AttrFn}     = "GoECharger_Attr";
    $hash->{AttrList}   = "interval ".
                          "disable:1 ".
                          "used_api_keys ".
                          $readingFnAttributes;
    
    foreach my $d(sort keys %{$modules{GoECharger}{defptr}}) {
    
        my $hash = $modules{GoECharger}{defptr}{$d};
        $hash->{VERSION}      = $version;
    }
}

sub GoECharger_Define($$) {

    my ( $hash, $def ) = @_;
    
    my @a = split( "[ \t][ \t]*", $def );
   
    return "too few parameters: define <name> GoECharger <CLOUDTOKEN>" if( @a != 3);
    return "Cannot define a GoECharger device. Perl modul $missingModul is missing." if ( $missingModul );
    
    my $name                = $a[0];
    
    my $token               = $a[2];
    #$hash->{HOST}           = $host;
    $hash->{CLOUDTOKEN}     = $token;
    $hash->{INTERVAL}       = 60;
    $hash->{VERSION}        = $version;
    $hash->{NOTIFYDEV}      = "global";
    $hash->{ActionQueue}    = [];

    
    CommandAttr(undef,$name.' room Energie');# if ( AttrVal($name,'room','') ne '' );
    Log3 $name, 3, "GoECharger ($name) - defined GoECharger Device with Interval $hash->{INTERVAL}"; #Port $hash->{PORT}
    
    #$modules{GoECharger}{defptr}{HOST} = $hash;
    $modules{GoECharger}{defptr}{CLOUDTOKEN} = $hash;
    
    # API related internals and attrib
    #GoECharger_API_V15($hash);
    $hash->{USED_API_KEYS}  = $reading_keys_json_default;
    CommandAttr(undef,$name.' used_api_keys default');
    #  generic attrib
    CommandAttr(undef,$name.' devStateIcon '.$icodef);
    CommandAttr(undef,$name.' interval '.$hash->{INTERVAL});
    return undef;
}

sub GoECharger_Undef($$) {

    my ( $hash, $arg )  = @_;
    
    my $name            = $hash->{NAME};


    Log3 $name, 3, "GoECharger ($name) - Device $name deleted";
    delete $modules{GoECharger}{defptr}{CLOUDTOKEN} if( defined($modules{GoECharger}{defptr}{CLOUDTOKEN}) and $hash->{CLOUDTOKEN} );

    return undef;
}

sub GoECharger_Attr(@) {

    my ( $cmd, $name, $attrName, $attrVal ) = @_;
    my $hash = $defs{$name};


    if( $attrName eq "disable" ) {
        if( $cmd eq "set" and $attrVal eq "1" ) {
            RemoveInternalTimer($hash);
            readingsSingleUpdate ( $hash, "state", "disabled", 1 );
            Log3 $name, 3, "GoECharger ($name) - disabled";
        
        } elsif( $cmd eq "del" ) {
            Log3 $name, 3, "GoECharger ($name) - enabled";
        }
    }
    
    if( $attrName eq "disabledForIntervals" ) {
        if( $cmd eq "set" ) {
            return "check disabledForIntervals Syntax HH:MM-HH:MM or 'HH:MM-HH:MM HH:MM-HH:MM ...'"
            unless($attrVal =~ /^((\d{2}:\d{2})-(\d{2}:\d{2})\s?)+$/);
            Log3 $name, 3, "GoECharger ($name) - disabledForIntervals";
            readingsSingleUpdate ( $hash, "state", "disabled", 1 );
        
        } elsif( $cmd eq "del" ) {
            Log3 $name, 3, "GoECharger ($name) - enabled";
            readingsSingleUpdate( $hash, "state", "active", 1 );
        }
    }
    
  
  if( $attrName eq "used_api_keys" ) {
        if( $cmd eq "set" ) {
            if ($attrVal eq 'default'){
                $reading_keys_json=$reading_keys_json_default;
            }elsif($attrVal eq 'minimal'){
                $reading_keys_json=$reading_keys_json_minimal;
            }elsif($attrVal eq 'allkeys'){
                $reading_keys_json=$reading_keys_json_allkeys;
            }else{
                $reading_keys_json=$attrVal;
            }
        } elsif( $cmd eq "del" ) {
            $reading_keys_json=$reading_keys_json_default;
        }
        $hash->{USED_API_KEYS}  = $reading_keys_json;
        # delete all readings
        {fhem ("deletereading $name .*")};
        
        return 'There are still path commands in the action queue'
            if( defined($hash->{ActionQueue}) and scalar(@{$hash->{ActionQueue}}) > 0 );
        unshift( @{$hash->{ActionQueue}}, 'status' );
        GoECharger_GetData($hash);          
    }

    if( $attrName eq "interval" ) {
        if( $cmd eq "set" ) {
            if( $attrVal < 5 ) {
                Log3 $name, 3, "GoECharger ($name) - interval too small, please use something >= 5 (sec), default is 60 (sec)";
                return "interval too small, please use something >= 5 (sec), default is 60 (sec)";
            
            } else {
                RemoveInternalTimer($hash);
                $hash->{INTERVAL} = $attrVal;
                Log3 $name, 3, "GoECharger ($name) - set interval to $attrVal";
                GoECharger_Timer_GetData($hash);
            }
        } elsif( $cmd eq "del" ) {
            RemoveInternalTimer($hash);
            $hash->{INTERVAL} = 60;
            Log3 $name, 3, "GoECharger ($name) - set interval to default";
            GoECharger_Timer_GetData($hash);
        }
    }
    
    return undef;
}

sub GoECharger_Notify($$) {

    my ($hash,$dev) = @_;
    my $name = $hash->{NAME};
    return if (IsDisabled($name));
    
    my $devname = $dev->{NAME};
    my $devtype = $dev->{TYPE};
    my $events = deviceEvents($dev,1);
    return if (!$events);

    GoECharger_Timer_GetData($hash) if( grep /^INITIALIZED$/,@{$events}
                                                or grep /^DELETEATTR.$name.disable$/,@{$events}
                                                or grep /^DELETEATTR.$name.interval$/,@{$events}
                                                or (grep /^DEFINED.$name$/,@{$events} and $init_done) );
    return;
}

sub GoECharger_Get($@) {
    
    my ($hash, $name, $cmd) = @_;
    my $arg;

    if( $cmd eq 'status' ) {
        $arg    = lc($cmd);
    } else {  
        my $list = 'status:noArg';       
        return "Unknown argument $cmd, choose one of $list";
    }
    
    return 'There are still path commands in the action queue'
    if( defined($hash->{ActionQueue}) and scalar(@{$hash->{ActionQueue}}) > 0 );
    
    unshift( @{$hash->{ActionQueue}}, $arg );
    GoECharger_GetData($hash);

    return undef;
}

sub GoECharger_Set($@) {
    
    my ($hash, $name, $cmd, $arg) = @_;
    my $queue_cmd='';
    my $setpath='payload='; #amp=7
    
    if( $cmd eq 'allow_charging' ) {
        if (($arg == 0) or ($arg==1)){
            $queue_cmd  = $setpath.'alw='.$arg;
        }else{
            return "Arg $arg not allowed for $cmd";
        }
        
    }elsif( $cmd eq 'amp_current' ) {
        if (($arg >= 6) and ($arg<=32)){
            $queue_cmd  = $setpath.'amp='.$arg;
        }else{
            return "Arg $arg not allowed for $cmd";
        }
                
    }elsif( $cmd eq 'stop_at_num_kWh' ) {
        if (($arg >= 0)){
            $queue_cmd  = $setpath.'dwo='.$arg*10;
        }else{
            return "Arg $arg not allowed for $cmd";
        }
        
    }elsif( $cmd eq 'led_brightness' ) {
        if (($arg >= 0) and ($arg<=255)){
            $queue_cmd  = $setpath.'lbr='.$arg;
        }else{
            return "Arg $arg not allowed for $cmd";
        }
        
    }elsif( $cmd eq 'led_color_idle' ) {
        if ($arg ne ''){
            $queue_cmd  = $setpath.'cid='.hex($arg);
        }else{
            return "Arg $arg not allowed for $cmd";
        }
        
    }elsif( $cmd eq 'led_color_charge' ) {
        if ($arg ne ''){
            $queue_cmd  = $setpath.'cch='.hex($arg);
        }else{
            return "Arg $arg not allowed for $cmd";
        }
        
    }elsif( $cmd eq 'led_color_finish' ) {
        if ($arg ne ''){
            $queue_cmd  = $setpath.'cfi='.hex($arg);
        }else{
            return "Arg $arg not allowed for $cmd";
        }
        
    }elsif( $cmd eq 'led_save_energy' ) {
        if (($arg == 0) or ($arg==1)){
            $queue_cmd  = $setpath.'r2x='.$arg; #r2x instead of lse
        }else{
            return "Arg $arg not allowed for $cmd";
        }

    }elsif( $cmd eq 'access_control_state' ) { #
        if ($arg eq 'access_open') {
                $arg=0;
                $queue_cmd  = $setpath.'ast='.$arg;
        }elsif($arg eq 'by_RFID_or_App'){
                $arg=1;
                $queue_cmd  = $setpath.'ast='.$arg;
        }elsif($arg eq 'price_or_auto'){
                $arg=2;
                $queue_cmd  = $setpath.'ast='.$arg;
        }else{
            return "Arg $arg not allowed for $cmd";
        }

    }elsif( $cmd eq 'cable_lock_state_at_box' ) { #while_car_present,while_charging,locked_always
        if ($arg eq 'while_car_present') {
                $arg=0;
                $queue_cmd  = $setpath.'ust='.$arg;
        }elsif($arg eq 'while_charging'){
                $arg=1;
                $queue_cmd  = $setpath.'ust='.$arg;
        }elsif($arg eq 'locked_always'){
                $arg=2;
                $queue_cmd  = $setpath.'ust='.$arg;
        }else{
            return "Arg $arg not allowed for $cmd";
        }
    
    }elsif( $cmd eq 'byPrice_till_oclock_charge' ) {
        if (($arg >= 0) and ($arg<=24)){
            $queue_cmd  = $setpath.'afi='.$arg;
        }else{
            return "Arg $arg not allowed for $cmd";
        }

    }elsif( $cmd eq 'byPrice_min_hrs_charge' ) {
        if (($arg >= 0) and ($arg<=23)){
            $queue_cmd  = $setpath.'aho='.$arg;
        }else{
            return "Arg $arg not allowed for $cmd";
        }
        
    }elsif( $cmd eq 'amp_max_wallbox' ) {
        if (($arg >= 6) and ($arg<=32)){
            $queue_cmd  = $setpath.'ama='.$arg;
        }else{
            return "Arg $arg not allowed for $cmd";
        }

    }elsif( $cmd eq 'ap_password' ) {
        if ((length($arg) >=6) and (length($arg)<=12)){
            $queue_cmd  = $setpath.'wak='.$arg;
        }else{
            return "Arg $arg not allowed for $cmd";
        }
        
    } else {
    
        my $list = "allow_charging:0,1 amp_current:slider,6,1,$maxamp led_brightness:slider,0,5,255 led_color_chg:colorpicker,RGB led_color_idle:colorpicker,RGB led_color_fin:colorpicker,RGB access_control_state:access_open,by_RFID_or_App,price_or_auto cable_lock_state_at_box:while_car_present,locked_always,while_charging stop_at_num_kWh:slider,0,1,80 led_save_energy:0,1 byPrice_till_oclock_charge:slider,0,1,24 byPrice_min_hrs_charge:slider,0,1,23 amp_max_wallbox:slider,6,1,32 ap_password";  
        
        return "Unknown argument $cmd, choose one of $list";
    }
    
    return 'There are still path commands in the action queue'
    if( defined($hash->{ActionQueue}) and scalar(@{$hash->{ActionQueue}}) > 0 );
    
    unshift( @{$hash->{ActionQueue}}, $queue_cmd) if ($queue_cmd ne '');
    GoECharger_GetData($hash);

    return undef;
}


sub GoECharger_Timer_GetData($) {

    my $hash    = shift;
    my $name    = $hash->{NAME};


    if( defined($hash->{ActionQueue}) and scalar(@{$hash->{ActionQueue}}) == 0 ) {
        if( not IsDisabled($name) ) {
            while( my $obj = each %paths ) {
                unshift( @{$hash->{ActionQueue}}, $obj );
            }
        
            GoECharger_GetData($hash);
        
        } else {
            readingsSingleUpdate($hash,'Http_state','disabled',1);
        }
    }
    
    InternalTimer( gettimeofday()+$hash->{INTERVAL}, 'GoECharger_Timer_GetData', $hash );
    Log3 $name, 4, "GoECharger ($name) - Call InternalTimer GoECharger_Timer_GetData";
}

sub GoECharger_GetData($) {

    my ($hash)          = @_;
    
    my $name            = $hash->{NAME};
    #my $host            = $hash->{HOST};
    my $token            = $hash->{CLOUDTOKEN};
    my $path            = pop( @{$hash->{ActionQueue}} );
    #my $uri             = $host.'/'.$path;
    my $uri             = "api.go-e.co/api_status?token=$token";

    readingsSingleUpdate($hash,'Http_state','fetch data - ' . scalar(@{$hash->{ActionQueue}}) . ' entries in the Queue',1);

    # "status" is the same call when directly connected to the box. But when using the cloud API, it's a different URI.
    if ( $path ne "status" ) {
        Log3 $name, 4, "GoECharger ($name) - path is set as '$path'";
        $uri = "api.go-e.co/api?token=$token&$path";
    }

    HttpUtils_NonblockingGet(
        {
            url         => "https://" . $uri,
            timeout     => 5,
            method      => 'GET',
            hash        => $hash,
            setCmd      => $path,
            doTrigger   => 1,
            callback    => \&GoECharger_ErrorHandling,
        }
    );
    
    Log3 $name, 4, "GoECharger ($name) - Send with URI: https://$uri";
}

sub GoECharger_ErrorHandling($$$) {

    my ($param,$err,$data)  = @_;
    
    my $hash                = $param->{hash};
    my $name                = $hash->{NAME};


    ### Begin Error Handling
    
    if( defined( $err ) ) {
        if( $err ne "" ) {
        
            readingsBeginUpdate( $hash );
            readingsBulkUpdate( $hash, 'Http_state', $err, 1);
            readingsBulkUpdate( $hash, 'Http_lastRequestError', $err, 1 );
            readingsEndUpdate( $hash, 1 );
            
            Log3 $name, 3, "GoECharger ($name) - RequestERROR: $err";
            
            $hash->{ActionQueue} = [];
            return;
        }
    }

    if( $data eq "" and exists( $param->{code} ) && $param->{code} ne 200 ) {
    
        readingsBeginUpdate( $hash );
        readingsBulkUpdate( $hash, 'Http_state', $param->{code}, 1 );

        readingsBulkUpdate( $hash, 'Http_lastRequestError', $param->{code}, 1 );

        Log3 $name, 3, "GoECharger ($name) - RequestERROR: ".$param->{code};

        readingsEndUpdate( $hash, 1 );
    
        Log3 $name, 5, "GoECharger ($name) - RequestERROR: received http code ".$param->{code}." without any data after requesting";

        $hash->{ActionQueue} = [];
        return;
    }

    if( ( $data =~ /Error/i ) and exists( $param->{code} ) ) { 
    
        readingsBeginUpdate( $hash );
        
        readingsBulkUpdate( $hash, 'Http_state', $param->{code}, 1 );
        readingsBulkUpdate( $hash, "Http_lastRequestError", $param->{code}, 1 );

        readingsEndUpdate( $hash, 1 );
    
        Log3 $name, 3, "GoECharger ($name) - http error ".$param->{code};

        $hash->{ActionQueue} = [];
        return;
        ### End Error Handling
    }
    
    GoECharger_GetData($hash)
    if( defined($hash->{ActionQueue}) and scalar(@{$hash->{ActionQueue}}) > 0 );
    
    Log3 $name, 4, "GoECharger ($name) - Receive JSON data: $data";
    
    GoECharger_ResponseProcessing($hash,$param->{setCmd},$data);
}

sub GoECharger_ResponseProcessing($$$) {

    my ($hash,$path,$json)        = @_;
    
    my $name                = $hash->{NAME};
    my $decode_json;
    my $responsedata;


    $decode_json    = eval{decode_json($json)};
    if($@){
        Log3 $name, 4, "GoECharger ($name) - error while request: $@";
        readingsBeginUpdate($hash);
        readingsBulkUpdate($hash, 'JSON Error', $@);
        readingsBulkUpdate($hash, 'Http_state', 'JSON error');
        readingsEndUpdate($hash,1);
        return;
    }
    
    #### Verarbeitung der Readings zum passenden Path
    
    $responsedata = $decode_json;
    GoECharger_WriteReadings($hash,$path,$responsedata);
}

sub GoECharger_WriteReadings($$$) {

    my ($hash,$path,$responsedata)    = @_;    
    my $name = $hash->{NAME};    
    Log3 $name, 4, "GoECharger ($name) - Write Readings";
    
    Log3 $name, 5, "GoECharger ($name) - JSON-Dumper: " . Dumper $responsedata;

    my $newreadingname;
    my $numphases = 0;
    my $tmpstate;
    $reading_keys_json=$hash->{USED_API_KEYS};
    my @reading_keys=split(/ /,$reading_keys_json);
    readingsBeginUpdate($hash);
    
    foreach my $datakey ( keys %{ $responsedata->{'data'} } ) {
        my $value = $responsedata->{'data'}{$datakey};
        Log3 $name, 5, "GoECharger ($name) - value of $datakey: $value";

        # Look up a friendly reading name
        $newreadingname=$goevar{$datakey};
        Log3 $name, 5, "GoECharger ($name) - newreadingname: $newreadingname";
        $newreadingname=$datakey if ($newreadingname eq '');

        # Improve value output (mor readable, hopefully)
        $value = sprintf( "%.1f", $value/10 )         if  $datakey eq "eto";
        $value = sprintf( "%.1f", $value/360_000 )    if  $datakey eq "dws";
        $value = sprintf( "%.1f", $value/10 )         if  $datakey eq "dwo";
        $value = sprintf( "%.2f", $value/3_600_000 )  if  $datakey eq "dto";
        $value = sprintf( "%06X", $value )            if  $datakey eq "cid" or $datakey eq "cch" or $datakey eq "cfi";

        # Access control state
        if ( $datakey eq "ast" ) {
            if    ( $value == 0 )  { $value = "access_open"; }
            elsif ( $value == 1 )  { $value = "by_RFID_or_App"; }
            elsif ( $value == 2 )  { $value = "price_or_auto"; }
            else                   { $value = "*unknown*"; }
        }

        # Phases available
        if ( $datakey eq "pha" ) {
            $numphases++ if ($value & 8)==8;
            $numphases++ if ($value & 16)==16;
            $numphases++ if ($value & 32)==32;
            $value = sprintf( "%b", $value );  # show binary
        }

        # Calculating energy
        if ( $datakey eq "nrg" ) {
            my @vtmp = @{ $responsedata->{'data'}{'nrg'} };
            my $tmpr = "KW_charging_measured";
            my $tmpv = sprintf( "%.2f", $vtmp[11]/100 );
            readingsBulkUpdate( $hash, $tmpr, $tmpv );
        }

        # Cable lock state at box
        if ( $datakey eq "ust" ) {
            if    ( $value == 0 )  { $value = "while_car_present"; }
            elsif ( $value == 1 )  { $value = "while_charging"; }
            elsif ( $value == 2 )  { $value = "locked_always"; }
            else                   { $value = "*unknown*"; }
        }
        
        readingsBulkUpdate( $hash, $newreadingname, $value );
    }

    # calculate available power at 230V~
    readingsBulkUpdate($hash,'KW_preset_calculated',sprintf("%.2f",($responsedata->{'data'}->{'amp'})*$numphases*0.230)) if(defined($responsedata->{'data'}{'amp'}));

    # create state derived from 'alw' and 'car'
    my $tmpv=sprintf("%d",($responsedata->{'data'}->{car}));
    if ($tmpv ==1){
        if (($responsedata->{'data'}->{alw})==1){
            $tmpstate='ready_no_car';
        }else{
            $tmpstate='not_allowed';
        }
    }elsif($tmpv ==2){
        $tmpstate='charging';
    }elsif($tmpv ==3){
        $tmpstate='waiting_for_car';
    }elsif($tmpv ==4){
        $tmpstate='finished';
    }else{
        $tmpstate='unknown';
    }
    if (sprintf("%d",($responsedata->{'data'}->{err})) >0){
        $tmpstate='error';
    }
    readingsBulkUpdate($hash,'state',$tmpstate);
    
    #readingsBulkUpdateIfChanged($hash,'ActionQueue',scalar(@{$hash->{ActionQueue}}) . ' entries in the Queue');
    readingsBulkUpdateIfChanged($hash,'Http_state',(defined($hash->{ActionQueue}) and scalar(@{$hash->{ActionQueue}}) == 0 ? 'ready' : 'fetch data - ' . scalar(@{$hash->{ActionQueue}}) . ' paths in ActionQueue'));
    readingsEndUpdate($hash,1);
}


1;


=pod

=item device
=item summary       Modul to control Go-ECharger wallbox
=begin html

<a name="GoECharger"></a>
<h3>GoECharger</h3>
<ul>
    <u><b>GoECharger - control a Go-eCharger wallbox</b></u>
    <br>
    With this module it is possible to read data and set some functions of the wallbox to monitor and control car charging.<br>
    Create a FileLog device if desired.<br>
    <br><br>
    <a name="GoEChargerdefine"></a>
    <b>Define</b>
    <ul><br>
        <code>define &lt;name&gt; GoECharger &lt;hostip&gt;</code>
    <br><br>
    Example:
    <br>
        <code>define myGoE GoECharger 192.168.1.34</code><br>
    <br>
    This statement creates a device with the name myGoE and the Host IP 192.168.1.34 and a default polling interval of 60 sec.<br>
    After the device has been created, the current data of the go-Echarger are automatically read and default readings will be generated.<br>
    </ul>
    <br><br>
    <a name="GoEChargerreadings"></a>
    <b>Readings</b>
    <ul>
        At default only some readings are present. The 'state' reading is derived from JSON API keys 'car' and 'alw'.<br>
        The original "xxx" JSON API key will be appended with a description to show as reading. <br>
        All, default and your personal key selection and the resulting readings are configurable via Attribute "used_api_keys".<br>
        Readings starting with uppercase letter are generated by the module.<br>
        <br>
            <li>Http_state      - information about last Http request</li>
            <li>KW_charging_measured      - measured power (kW), derived from 'nrg' array</li>
            <li>KW_preset_calculated      - calculated power (kW), calculated with phases, amp and 230V</li>
        <br>    
        With firmware 033 the following JSON API keys are known and generate a readingname.<br>
        API-Key = readingname (description):<br>
        -------------------------------------------------------<br>
        <li>adi = amp_max16A_adapter &nbsp&nbsp&nbsp&nbspa(limiting adapter in use)</li>
        <li>afi = byPrice_till_oclock_charge &nbsp&nbsp&nbsp&nbsp(charge by price till x o'clock)</li>
        <li>aho = byPrice_min_hrs_charge &nbsp&nbsp&nbsp&nbsp(charge by price min x hrs till ... see 'afi')</li>
        <li>al1 = amp_lvl01</li>
        <li>al2 = amp_lvl02</li>
        <li>al3 = amp_lvl03</li>
        <li>al4 = amp_lvl04</li>
        <li>al5 = amp_lvl05</li>
        <li>alw = allow_charging&nbsp&nbsp&nbsp&nbsp(0=activate otherwise...see 'ast', 1=activate manual)</li>
        <li>ama = amp_max_wallbox &nbsp&nbsp&nbsp&nbsp(house related limit <=32A)</li>
        <li>amp = amp_current   &nbsp&nbsp&nbsp&nbsp(the actual charge current per phase)</li>
        <li>amt = amp_limit_by_temp &nbsp&nbsp&nbsp&nbsp(controller may limit charge current, otherwise max is 32A)</li> 
        <li>ast = access_control_state &nbsp&nbsp&nbsp&nbsp(access_open,by_RFID_or_App,price_or_auto)</li>
        <li>azo = aWattar_zone &nbsp&nbsp&nbsp&nbsp(aWattar price zone 0 = Austria, 1 = Germany)</li>
        <li>car = car_state &nbsp&nbsp&nbsp&nbsp(1 = ready_no_car, 2 = charging, 3 =  waiting_for_car, 4 = finished)</li>
        <li>cbl = amp_max_cable</li>
        <li>cch = led_color_chg &nbsp&nbsp&nbsp&nbsp(LED color while charging, RGB, converted to HEX for colorpicker)</li>
        <li>cdi = cloud_disabled</li>
        <li>cfi = led_color_fin &nbsp&nbsp&nbsp&nbsp(LED color if finished, RGB, converted to HEX for colorpicker)</li>
        <li>cid = led_color_idle &nbsp&nbsp&nbsp&nbsp(LED color at standby, RGB, converted to HEX for colorpicker)</li>
        <li>dto = byPrice_remain_hrs_start_charge &nbsp&nbsp&nbsp&nbsp(remaining time in hours till start charging by price)</li>
        <li>dwo = stop_at_num_kWh &nbsp&nbsp&nbsp&nbsp(charge only x kWh, recalculated to kWh, divided by 10)</li>
        <li>dws = kWh_charged_last &nbsp&nbsp&nbsp&nbsp(if cable connected: last charged kWh, else 0 , recalculated to kW from dekawattsec)</li>
        <li>ec1 = energy_card10 &nbsp&nbsp&nbsp&nbsp(total energy loaded by this card kWh*10, 140 means 14 kWh)</li>
        <li>ec4 = energy_card04 &nbsp&nbsp&nbsp&nbsp(total energy loaded by this card kWh*10, 140 means 14 kWh)</li>
        <li>ec5 = energy_card05 &nbsp&nbsp&nbsp&nbsp(total energy loaded by this card kWh*10, 140 means 14 kWh)</li>
        <li>ec6 = energy_card06 &nbsp&nbsp&nbsp&nbsp(total energy loaded by this card kWh*10, 140 means 14 kWh)</li>
        <li>ec7 = energy_card07 &nbsp&nbsp&nbsp&nbsp(total energy loaded by this card kWh*10, 140 means 14 kWh)</li>
        <li>ec8 = energy_card08 &nbsp&nbsp&nbsp&nbsp(total energy loaded by this card kWh*10, 140 means 14 kWh)</li>
        <li>ec9 = energy_card09 &nbsp&nbsp&nbsp&nbsp(total energy loaded by this card kWh*10, 140 means 14 kWh)</li>
        <li>eca = energy_card01 &nbsp&nbsp&nbsp&nbsp(total energy loaded by this card kWh*10, 140 means 14 kWh)</li>
        <li>ecd = energy_card03 &nbsp&nbsp&nbsp&nbsp(total energy loaded by this card kWh*10, 140 means 14 kWh)</li>
        <li>ecr = energy_card02 &nbsp&nbsp&nbsp&nbsp(total energy loaded by this card kWh*10, 140 means 14 kWh)</li>
        <li>err = error</li>
        <li>eto = kWh_charged_total&nbsp&nbsp&nbsp&nbsp(total energy charged by wallbox recalculated to kWh, divided by 10)</li>
        <li>fwv = firmware &nbsp&nbsp&nbsp&nbsp(version e.g. 033)</li>
        <li>lbr = led_brightness &nbsp&nbsp&nbsp&nbsp(brightness between 0=dark and full bright=255)</li>
        <li>lch = load_mgmt_sec</li>
        <li>loa = load_mgmt_curramp</li>
        <li>loe = cloud_mgmt</li>
        <li>lof = load_mgmt_fallbckamp</li>
        <li>log = load_mgmt_grp</li>
        <li>lom = load_mgmt_minamp</li>
        <li>lon = load_mgmt_num</li>
        <li>lop = load_mgmt_prio</li>
        <li>lot = load_mgmt_grpamp5</li>
        <li>lse = led_save_energy</li>
        <li>mcc = mqtt_rdy</li>
        <li>mce = mqtt_enabled</li>
        <li>mck = mqtt_key</li>
        <li>mcp = mqtt_port</li>
        <li>mcs = mqtt_srv</li>
        <li>mcu = mqtt_user</li>
        <li>nmo = norway_mode &nbsp&nbsp&nbsp&nbsp(don't check earth grounding, only at IT grid e.g. at Norway)</li>
        <li>nrg = energy_sensors &nbsp&nbsp&nbsp&nbsp(array, at this time only nrg[11] used for measured kW)</li>
        <li>pha = phases_available &nbsp&nbsp&nbsp&nbsp(presented as binary L1,L2,L3,L1,L2,L3 - right ones car side behind relay)</li>
        <li>r1x = wifi_flags</li>
        <li>rbc = reboot_counter</li>
        <li>rbt = reboot_timer</li>
        <li>rc1 = id_card10 &nbsp&nbsp&nbsp&nbsp(card id number)</li>
        <li>rc4 = id_card04 &nbsp&nbsp&nbsp&nbsp(card id number)</li>
        <li>rc5 = id_card05 &nbsp&nbsp&nbsp&nbsp(card id number)</li>
        <li>rc6 = id_card06 &nbsp&nbsp&nbsp&nbsp(card id number)</li>
        <li>rc7 = id_card07 &nbsp&nbsp&nbsp&nbsp(card id number)</li>
        <li>rc8 = id_card08 &nbsp&nbsp&nbsp&nbsp(card id number)</li>
        <li>rc9 = id_card09 &nbsp&nbsp&nbsp&nbsp(card id number)</li>
        <li>rca = id_card01 &nbsp&nbsp&nbsp&nbsp(card id number)</li>
        <li>rcd = id_card03 &nbsp&nbsp&nbsp&nbsp(card id number)</li>
        <li>rcr = id_card02 &nbsp&nbsp&nbsp&nbsp(card id number)</li>
        <li>rn1 = name_card10 &nbsp&nbsp&nbsp&nbsp(card name)</li>
        <li>rn4 = name_card04 &nbsp&nbsp&nbsp&nbsp(card name)</li>
        <li>rn5 = name_card05 &nbsp&nbsp&nbsp&nbsp(card name)</li>
        <li>rn6 = name_card06 &nbsp&nbsp&nbsp&nbsp(card name)</li>
        <li>rn7 = name_card07 &nbsp&nbsp&nbsp&nbsp(card name)</li>
        <li>rn8 = name_card08 &nbsp&nbsp&nbsp&nbsp(card name)</li>
        <li>rn9 = name_card09 &nbsp&nbsp&nbsp&nbsp(card name)</li>
        <li>rna = name_card01 &nbsp&nbsp&nbsp&nbsp(card name)</li>
        <li>rne = name_card03 &nbsp&nbsp&nbsp&nbsp(card name)</li>
        <li>rnm = name_card02 &nbsp&nbsp&nbsp&nbsp(card name)</li>
        <li>sch = schedule</li>
        <li>sdp = sched_dbl_press</li>
        <li>sse = serial_nr     &nbsp&nbsp&nbsp&nbsp(serial number of the wallbox)</li>
        <li>stp = stop_kWh_state&nbsp&nbsp&nbsp&nbsp(at this time useless)</li>
        <li>tds = daylights_time_offset</li>
        <li>tma = curr_sense_Typ2</li>
        <li>tme = clock_time    &nbsp&nbsp&nbsp&nbsp(String of date and time DDMMYYHHMM)</li>
        <li>tmp = temperature   &nbsp&nbsp&nbsp&nbsp(controller temperature)</li>
        <li>tof = gmt_time_offset</li>
        <li>txi = transmit_interface &nbsp&nbsp&nbsp&nbsp(last interface used to send state)</li>
        <li>uby = unlocked_by_card &nbsp&nbsp&nbsp&nbsp(the last id number of card used to get access)</li>
        <li>ust = cable_lock_state_at_box &nbsp&nbsp&nbsp&nbsp(cable locked at box:while_car_present(normal), while_charging, locked_always)</li>
        <li>version = version &nbsp&nbsp&nbsp&nbsp(used for encryption)</li>
        <li>wak = ap_password &nbsp&nbsp&nbsp&nbsp(password to access local wallbox wifi accesspoint)</li>
        <li>wen = wifi_enabled</li>
        <li>wke = wlan_key</li>
        <li>wss = wlan_ssid</li>
        <li>wst = wifi_state</li>
    </ul>
    <a name="GoEChargerset"></a>
    <b>set</b>
    <ul>
        It's recommended to check if the reading is present, before set a value...<br>
        <li>allow_charging              - set wallbox ready to charge a car (set PWM signal at Typ2)</li>
        <li>amp_current                 - set the actual current to use for charging (may be limited by adapter and cablee)</li>
        <li>stop_num_kWh                - stop charging after a number of kWh</li>
        <li>led_brightn                 - set LED brightness min=0, max=255 (see also led_save_energy above)</li>
        <li>led_color_chg               - set LED color at charging (as RGB Hex)</li>
        <li>led_color_idle              - set LED color at idle (as RGB Hex)</li>
        <li>led_color_fin               - set LED color at the end of charging (as RGB Hex)</li>
        <li>access_control_state        - set access to wallbox: 0= open, 1= RFID/App, 2= byPrice/automatic</li>
        <li>cable_unlock_state          - set when cable is locked at the box: 0= if car present, 1= while charging, 2= everytime</li>
        <li>byPrice_till_oclock_charge  - set clock hour when charging by price has to be finished</li>
        <li>byPrice_min_hrs_charge      - set the minimum desired hours for charging by price</li>
        <li>amp_max_wallbox             - set max current limit in Amp of your wallbox related to fuse, installation or house</li>
        <li>ap_password                 - change the on site local wallbox wifi accesspoint password (here checked as 6...12 char)</li>
    </ul>
    <a name="GoEChargerget"></a>
    <b>get</b>
    <ul>
        <li>status                      - fetch data now (same procedure as at interval)</li>
    </ul>
    <a name="GoEChargerattribute"></a>
    <b>Attribute</b>
    <ul>
        <li>interval                    - interval in seconds for automatically fetch data (default 60, min. 5)</li>
        <li>used_api_keys               - use predefined sets of JSON API keys which will be shown as readings: <br>
        use predefined settings 'default', 'minima'l or 'all' ore define your own space separetet list of JSON API keys<br>
        (see above or API reference or Internal [UsedAPIKeys] for examples).</li>
        Examples:<br>
        <code>attr &lt;name&gt; &lt;used_api_keys&gt; &lt;default&gt;</code><br>
        <code>attr &lt;name&gt; &lt;used_api_keys&gt; &lt;minimal&gt;</code><br>
        <code>attr &lt;name&gt; &lt;used_api_keys&gt; &lt;all&gt;</code><br>
        <code>attr &lt;name&gt; &lt;used_api_keys&gt; &lt;alw amp ast car err eto ust&gt;</code><br>
    </ul>
</ul>

=end html
=begin html_DE

<a name="GoECharger"></a>
<h3>Go-eCharger</h3>

=end html_DE
=cut

