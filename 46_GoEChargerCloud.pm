###############################################################################
#       46_GoEChargerCloud.pm
#
#       (c) 2020 by Bernd Arnold     
#
#       This module can be used to get data from the go-eCharger API as specified in https://github.com/goecharger/go-eCharger-API-v1/blob/master/api_de.pdf
# 
#       This script is part of fhem.
#
#       Fhem is free software: you can redistribute it and/or modify
#       it under the terms of the GNU General Public License as published by
#       the Free Software Foundation, either version 2 of the License, or
#       (at your option) any later version.
#
#       Fhem is distributed in the hope that it will be useful,
#       but WITHOUT ANY WARRANTY; without even the implied warranty of
#       MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#       GNU General Public License for more details.
#
#       You should have received a copy of the GNU General Public License
#       along with fhem.  If not, see <http://www.gnu.org/licenses/>.
#
#       FHEM Forum: http://forum.fhem.de/
#
#########################################################################################################################
#
# Definition: define <name> GoEChargerCloud <CloudToken>
#
#########################################################################################################################


package main;
use strict;
use warnings;
use POSIX;
use Data::Dumper;
use Blocking;
use Time::HiRes qw(gettimeofday);
use LWP::UserAgent;
use HTTP::Cookies;
use JSON qw( decode_json );


# Versions History intern
my %vNotesIntern = (
  #"1.0.0"  => "xx.xx.2020  initial stable release ",
  "0.0.1"  => "01.07.2020  first revision",
);


sub
GoEChargerCloud_Initialize($)
{
  my ($hash) = @_;

  $hash->{DefFn}     = "GoEChargerCloud_Define";
  $hash->{ParseFn}   = "GoEChargerCloud_Parse";
  $hash->{UndefFn}   = "GoEChargerCloud_Undefine";
  $hash->{SetFn}     = "GoEChargerCloud_Set";
  $hash->{AttrList}  = $readingFnAttributes;
}

sub
GoEChargerCloud_Define($$)
{

  my ($hash, $def) = @_;
  my @a = split(/\s+/, $def);
  
  return "Wrong syntax: use define <name> GoEChargerCloud <CloudToken>" if(int(@a) < 2);
  
  my $cloud_token = $a[2];

  $hash->{interval} = 300;
  $hash->{cloud_token} = $cloud_token;

  delete($hash->{helper}{RUNNING_PID}) if(defined($hash->{helper}{RUNNING_PID}));

  
GoEChargerCloud_Parse($hash);
return undef;
}

sub
GoEChargerCloud_Undefine($$)
{
  my ($hash, $arg) = @_;

  RemoveInternalTimer($hash);

  BlockingKill($hash->{helper}{RUNNING_PID}) if(defined($hash->{helper}{RUNNING_PID}));

  return undef;
}

sub
GoEChargerCloud_Set($$)
{
  my ($hash, @a) = @_;
  return "\"set X\" needs at least an argument" if ( @a < 2 );
  my $name    = $a[0];
  my $opt     = $a[1];

  my $ua = LWP::UserAgent->new;

  my $payload = "$name=$opt";

  my $cloud_token = $hash->{cloud_token};

  my $api_status_page = $ua->get( "https://api.go-e.co/api?token=$cloud_token&payload=$payload" );
  return;
}

#################################################################################################################################
##  Hauptschleife BlockingCall
#################################################################################################################################
sub
GoEChargerCloud_Parse($)
{
  my ($hash) = @_;
  my $name     = $hash->{NAME};
  my $cloud_token = $hash->{cloud_token};
  my $timeout  = 30;
  
  Log3 $name, 4, "$hash->{NAME} - BlockingCall with timeout: $timeout s will be executed.";
  
  if (exists($hash->{helper}{RUNNING_PID})) {
      Log3 $name, 1, "$hash->{NAME} - Error: another BlockingCall is already running, can't start BlockingCall GoEChargerCloud_DoParse";
  }
  else
  {
      $hash->{helper}{RUNNING_PID} = BlockingCall("GoEChargerCloud_DoParse", $name, "GoEChargerCloud_ParseDone", $timeout, "GoEChargerCloud_ParseAborted", $hash);
  }

  RemoveInternalTimer($hash, "GoEChargerCloud_Parse ");
  InternalTimer(gettimeofday()+$hash->{interval}, "GoEChargerCloud_Parse", $hash, 0);

}

#################################################################################################################################
##  Datenabruf
#################################################################################################################################
sub
GoEChargerCloud_DoParse($)
{
  my ($name) = @_;
  my $hash = $defs{$name};
  my $cloud_token = $hash->{cloud_token};
  
  my  ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
  $year += 1900;
  $mon += 1;
  my $today = "$year-".sprintf("%02d", $mon)."-".sprintf("%02d", $mday)."T";

  Log3 $name, 4, "$name -> Start BlockingCall GoEChargerCloud_DoParse";
  
  my $ua = LWP::UserAgent->new;

  my $api_status_page = $ua->get( "https://api.go-e.co/api_status?token=$cloud_token" );

  # Daten müssen als Einzeiler zurückgegeben werden
  my $api_status_content = encode_base64( $api_status_page->content, "" );
  
  Log3 $name, 4, "$name -> BlockingCall GoEChargerCloud_DoParse finished";

  return "$name|$api_status_content";
}


#################################################################################################################################
##  Verarbeitung empfangene Daten, setzen Readings
#################################################################################################################################
sub
GoEChargerCloud_ParseDone($)
{
  my ($string) = @_;
  
  my @a = split("\\|",$string);
  my $hash = $defs{$a[0]};
  my $response = $a[1]?decode_base64($a[1]):"undefined";
  
  Log3 $hash->{NAME}, 4, "$hash->{NAME} -> Start BlockingCall GoEChargerCloud_ParseDone";
   
  #if ($response eq "undefined") {
  #    delete($hash->{helper}{RUNNING_PID});
  #    Log3 $hash->{NAME}, 4, "$hash->{NAME} -> Response undefined -> RUNNING_PID deleted";
  #    return;
  #}
   
  my  ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
  $year += 1900;
  $mon += 1;
  my $today = "$year-".sprintf("%02d", $mon)."-".sprintf("%02d", $mday)."T";

  # Auswerten des JSON 
  my $json_data = decode_json($response);
  Log3 $hash->{NAME}, 5, "$hash->{NAME} -> JSON response: ". Dumper $json_data;
  
  readingsBeginUpdate($hash);

  my $success = $json_data->{'success'};
  readingsBulkUpdate( $hash, "Success", $success );

  my $tme = $json_data->{'data'}->{'tme'};
  readingsBulkUpdate( $hash, "Date/time", $tme );

  my $dws = $json_data->{'data'}->{'dws'};
  my $kwh = 0;
  $kwh = sprintf( "%.2f", $dws / 3600 / 100 ) if $dws > 0;
  readingsBulkUpdate( $hash, "Geladene Energiemenge (kWh)", $kwh );

  my $amp = $json_data->{'data'}->{'amp'};
  readingsBulkUpdate( $hash, "Ampere", $amp );

  my $car = $json_data->{'data'}->{'car'};
  my $car_text = "unbekannt ($car)";
  my %car_hash = ( 1 => "Ladestation bereit, kein Fahrzeug verbunden",
                   2 => "Auto laedt",
                   3 => "Warte auf Fahrzeug",
                   4 => "Ladung beendet, Fahrzeug verbunden",
                 );
  $car_text = $car_hash{ $car } if ( $car_hash{ $car } );
  readingsBulkUpdate( $hash, "Ladestatus Auto", $car_text );

  my $leistung_total = $json_data->{'data'}->{'nrg'}->[11] / 100;
  readingsBulkUpdate( $hash, "Leistung gesamt (kW)", $leistung_total );

  readingsBulkUpdate( $hash, "state", "Test :)" );
  readingsBulkUpdate( $hash, "STATE", "Test :)" );

  readingsEndUpdate( $hash, 1 );

  Log3 $hash->{NAME}, 4, "$hash->{NAME} -> BlockingCall GoEChargerCloud_ParseDone finished";
  delete($hash->{helper}{RUNNING_PID});

return;
}

#################################################################################################################################
##  Timeout  BlockingCall
#################################################################################################################################
sub
GoEChargerCloud_ParseAborted($)
{
  my ($hash) = @_;

  Log3 $hash, 1, "$hash->{NAME} -> BlockingCall GoEChargerCloud_DoParse timed out";
  delete($hash->{helper}{RUNNING_PID});
}

1;

=end html

=begin html_DE

<a name="GoEChargerCloud"></a>
<h3>GoEChargerCloud</h3>
<ul>

  Dieses Modul holt die Vorhersagewerte für den aktuellen Tag aus dem SunnyPortal und stellt diese als Readings dar.

  Dieses Modul funktioniert nur mit dem SHM-Modul. Sie m&uuml;ssen das SHM-Modul verwenden, welches die Login-
  Informationen bereitstellt. Das SHMForecastRelative-Modul verwendet die Login-Daten vom SHM-Modul.

  <br><br>

  <a name="shmforecastrelativedefine"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; GoEChargerCloud &lt;SHM_Device&gt; [interval]</code>
    <br><br>

    Beispiel:
    <ul>
      <code>define PV_ForecastRelative GoEChargerCloud &lt;Sonnenstrom&gt; 300</code><br>
    </ul>
  </ul>
  <br>

</ul>

=end html_DE

=begin html

<a name="GoEChargerCloud"></a>
<h3>GoEChargerCloud</h3>
<ul>

  This module fetches the forecast data for the next 24 hours from the SunnyPortal and provides the data as readings.

  This module only works with the SHM module. You have to use the SHM module which provides the login information.
  The SHMForecastRelative module uses the login data from the SHM module.

  <br><br>

  <a name="shmforecastrelativedefine"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; GoEChargerCloud [interval]</code>
    <br><br>

    Example:
    <ul>
      <code>define PV_ForecastRelative GoEChargerCloud 300</code><br>
    </ul>
  </ul>
  <br>

</ul>

=end html


=cut

