##
# Supports most of phone functionality over the Web. No real
# speaking, only typing, but environment is easily recognizable.
#
# Uses two tables:
#  KPhoneParties - holds agents and clients.
#   realname - person real name
#   status - current status (ready, down, busy, onhold)
#   role - 'agent' or 'caller'
#  KPhoneSessions - holds sessions (communication sequences)
#   caller - session initiator
#   agent - answering agent
#   text - seq-indexed phrases
#   quotation - seq-indexed quotations
#   file - seq-indexed attached files
#   party - seq-indexed "who said what"
#
package Symphero::Objects::KPhone;
use strict;
use Symphero::Utils;
use Symphero::Objects;
use Symphero::MultiValueDB;

##
# Inheritance
#
use vars qw(@ISA);
@ISA=Symphero::Objects->load(objname => 'Action');

##
# Cookie names for agent and caller.
#
my $caller_cookie_name="kpcaller";
my $agent_cookie_name="kpagent";

##
# Processing standard commands. Called from derived object as a last step.
#
sub check_mode ($$)
{ my $self=shift;
  my $args=get_args(\@_);
  my $mode=$args->{mode};
  if($mode eq "show-status")
   { $self->show_status($args);
   }
  elsif($mode eq 'place-call')
   { $self->place_call($args);
   }
  elsif($mode eq 'take-call')
   { $self->take_call($args);
   }
  elsif($mode eq 'drop-call')
   { $self->drop_call($args);
   }
  elsif($mode eq 'agent-log-in')
   { $self->agent_log_in($args);
   }
  elsif($mode eq 'caller-log-in')
   { $self->caller_log_in($args);
   }
  elsif($mode eq 'log-out' || $mode eq 'logout')
   { $self->log_out($args);
   }
  elsif($mode eq 'store-text')
   { $self->store_text($args);
   }
  elsif($mode eq 'show-text')
   { $self->show_text($args);
   }
  elsif($mode eq 'show-party-info')
   { $self->show_party_info($args);
   }
  elsif($mode eq 'set-agent-status')
   { $self->set_agent_status($args);
   }
  else
   { throw Symphero::Errors::Page ref($self)."::check_mode - unknown mode=$mode";
   }
}

##
# Retrieves current chat status. One of 'ready', 'busy' or 'talking'.
#
sub get_status ($)
{ my $self=shift;
  my $args=get_args(\@_);
  my ($me,$party,$session)=$self->get_call_info;
  return 'talking' if $party;
  my $skill=$args->{skill} || $me->get('skill');
  $self->find_available_agent(skill => $skill) ? 'ready' : 'busy';
}

## ##
## # Checking if an agent available for calling. Can return one of 'ready', 'busy', 'down'.
## #
## sub agent_status ($)
## { my $self=shift;
##   my $args=get_args(\@_);
##   $self->find_available_agent($args) ? 'ready' : 'busy';
## }

##
# Returns sessions database
#
sub get_session_db ($)
{ my $self=shift;
  return $self->{sessiondb} if $self->{sessiondb};
  my $db=Symphero::MultiValueDB->new(dbh => $self->dbh, table => 'KPhoneSessions');
  $db->setid($self->{sessionid}) if $self->{sessionid};
  $self->{sessiondb}=$db;
  $db;
}

##
# Returns parties database
#
sub get_party_db ($)
{ my $self=shift;
  return $self->{partydb} if $self->{partydb};
  my $db=Symphero::MultiValueDB->new(dbh => $self->dbh, table => 'KPhoneParties');
  $self->{partydb}=$db;
  $db;
}

##
# Looks for available agent. Agent must have 'skill' if it was given.
#
sub find_available_agent ($;%)
{ my $self=shift;
  my $args=get_args(\@_);
  my $pdb=$self->get_party_db;
  my $skill=$args->{skill};
  my @agents;
  $pdb->setid('..DEMO..');
  if(time - $pdb->get('atime') > 60 && $pdb->get('status') eq 'talking')
   { $pdb->put(status => 'ready');
     $pdb->put(atime => time);
     my $pid=$pdb->get('party');
     $pdb->delete('party');
     $pdb->delete('session');
     $pdb->setid($pid);
     $pdb->put(status => 'down');
     $pdb->delete('party');
     $pdb->delete('session');
   }
  foreach my $id ($pdb->listids(status => 'ready'))
   { $pdb->setid($id);
     next unless $pdb->get('role') eq 'agent';
     next if $skill && ! $pdb->getsub(skill => $skill);
     if($id ne '..DEMO..' && time - $pdb->get('atime') > 300)
      { $self->close_party($pdb->id);
        next;
      }
     push(@agents,$id);
   }
  my $num=int(rand(@agents));
  $agents[$num];
}

##
# Displays current session status.
#
sub show_status ($)
{ my $self=shift;
  my $args=get_args(\@_);
  my $status=$self->get_status($args);
  $self->textout(text => $status, objargs => \@_);
}

##
# Placing a call.
#
sub place_call ($)
{ my $self=shift;
  my $args=get_args(\@_);
  my $config=$self->siteconfig;

  ##
  # At that point we should be registered as party already!
  #
  my $caller=$config->get('kp_caller');
  $caller || throw Symphero::Errors::Page
                   ref($self)."::place_call - party is not not available";

  ##
  # Checking status
  #
  my $caller_status=$caller->get('status');
  if($caller_status ne 'ready')
   { $self->object->display(path => $args->{error},
                            ERRSTR => "You can't place calls in '$caller_status' status"
                           ) if $args->{error};
     return;
   }

  ##
  # Looking for an available agent
  #
  my $skill=$args->{skill} || $caller->get('skill');
  my $agentid=$self->find_available_agent(skill => $skill);
  if(!$agentid)
   { $self->object->display(path => $args->{error},
                            ERRSTR => "No agent available"
                           ) if $args->{error};
     return;
   }

  ##
  # Marking that agent as busy. There is race condition here!
  #
  my $agent=$self->get_party_db;
  $agent->setid($agentid);
  $agent->put(status => 'ringing');
  $agent->put(party => $caller->id);
  $caller->put(status => 'ringing');
  $caller->put(party => $agentid);

  ##
  # Creating session to store conversation
  #
  my $session=$self->get_session_db;
  my $sessionid=$session->create;
  $session->put(caller => $caller->id);
  $session->put(agent => $agentid);
  $session->put(skill => $skill) if $skill;
  $session->put(status => 'ringing');
  $agent->put(session => $sessionid);
  $caller->put(session => $sessionid);

  ##
  # Ok, the call has been placed, awaiting for the agent to accept it.
  #
  $self->object->display(path => $args->{success}) if $args->{success};

  ##
  # In demo mode we pick the call up automatically
  #
  if($agent->id eq '..DEMO..')
   { $caller->put(status => 'talking');
     $agent->put(status => 'talking');
     $session->put(status => 'talking');
   }
}

##
# Hanging up the call
#
sub drop_call ($;%)
{ my $self=shift;
  my $args=get_args(\@_);
  my ($p1,$p2,$session)=$self->get_call_info;
  if(!$p1 || !$p2 || !$session)
   { $self->object->display(path => $args->{error}) if $args->{error};
     return 0;
   }
  $session->put(status => 'closed');
  $p1->put(status => 'ready');
  $p1->delete('session');
  $p1->delete('party');
  $p2->put(status => 'ready');
  $p2->delete('session');
  $p2->delete('party');
  $self->object->display(path => $args->{success}) if $args->{success};
  1;
}

##
# Sending new sentence.
#
sub store_text ($;%)
{ my $self=shift;
  my $args=get_args(\@_);
  my ($me,$party,$session)=$self->get_call_info;
  if(!$me || !$party || !$session)
   { $self->object->display(path => $args->{error}) if $args->{error};
     return 0;
   }

  ##
  # Getting and storing text
  #
  my $text=$args->{text};
  $text=~s/^\s*(.*?)\s*$/$1/;
  if(length($text))
   { my $config=$self->siteconfig;
     if($config->get('kp_agent'))
      { $session->putsub('atext', time, $text);
      }
     else
      { $session->putsub('ctext', time, $text);
      }
   }

  ##
  # Done.
  #
  $self->object->display(path => $args->{success}) if $args->{success};
}

##
# Showing conversation protocol.
#
sub show_text ($;%)
{ my $self=shift;
  my $args=get_args(\@_);
  my ($me,$party,$session)=$self->get_call_info;
  if(!$me || !$party || !$session)
   { $self->object->display(path => $args->{'error.path'}) if $args->{'error.path'};
     return 0;
   }
  my $ctext=$session->get('ctext');
  $ctext={} unless $ctext;
  my $atext=$session->get('atext');
  $atext={} unless $atext;
  my @text=sort { $args->{reverse} ? ($b->{when} <=> $a->{when}) : ($a->{when} <=> $b->{when}) }
           ( ( map { { text => $atext->{$_}, role => 'agent', when => $_ } }
                   keys %{$atext} )
           , ( map { { text => $ctext->{$_}, role => 'caller', when => $_ } }
                   keys %{$ctext} )
           );
  my $obj=$self->object;
  for(my $i=0; $i!=@text; $i++)
   { my $record=$text[$i];
     $obj->display(path => $args->{$record->{role}.'.path'},
                   TEXT => $record->{text} || '',
                   WHEN => $record->{when},
                   ROLE => $record->{role},
                   INDEX => $i,
                   LAST => ($i+1 == @text) ? 1 : 0);
   }

  ##
  # In DEMO mode we put some text on behalf of agent automatically.
  # Full blown artificial intelligence :)
  #
  if($party->id eq '..DEMO..')
   { my @intro=( "Thank you for calling WDSource.com premier online support!",
               , "How can I help you?"
               , "I'm only a robot made by WDSource.com for this presentation."
               , "Feel free to visit our real site at http://WDSource.com/ soon and talk with our real agents!"
               , "Thank you for stopping by..."
               );
     my @foo=( "How are you doing today?"
             , "How are you?"
             , "It's a great pleasure talking to you!"
             , "How can I help you?"
             , "How can I help you?"
             , "Don't worry, be happy!"
             , "What's the weather today?"
             , "I like your typing speed!"
             , "Good luck!"
             , "Do you want me to tell you a joke?"
             , "Never mind.."
             , "I'm only a robot you know.. It's so sad.."
             , "I'm only a robot you know.. It's so sad.."
             , "Come back later"
             , "WDSorce.com is always the best!"
             );
     my $step=scalar(keys %{$atext});
     my $text;
     if($step < @intro)
      { $text=$intro[$step];
      }
     elsif(ref($ctext))
      { my @times=sort { $b <=> $a } keys %{$ctext};
        my $pause=time - $times[0];
        if($pause > 75)
         {
         }
        elsif($pause > 70)
         { $text="Ok, you sleep - I sleep..";
         }
        elsif($pause > 60)
         { my @remind=( "Hey, are still here?"
                      , "Can I help you with anything? Please type in your question."
                      , "Can I help you with anything? Please type in your question."
                      );
           $text=@remind[rand(@remind)];
         }
        else
         { $text=@foo[rand(@foo)] if rand(10)<3;
         }
      }
     if($text)
      { $session->putsub('atext', time, $text);
        $party->update(atime => time);
      }
   }
}

##
# Logging in caller. It is up to something external to check
# permissions, we only make the caller ready to place calls here.
#
# Arguments:
#  email => caller's email
#  name => caller's real name or nickname
#  extid => caller's external id (for logged in customers for example)
# 
# Sets caller cookie and makes an entry in KPhoneParties. Returns caller
# ID and puts it into site configuration also as an 'kp_agent_id'.
#
sub caller_log_in ($;%)
{ my $self=shift;
  my $args=get_args(\@_);

  ##
  # Are we already available?
  #
  my $pdb=$self->get_party_db;
  my $id=$self->cgi->cookie($caller_cookie_name);
  $pdb->setid($id) if defined $id;
  if(!$args->{override} && $id && $pdb->valid)
   { $pdb->update(atime => time);
   }
  elsif(!$args->{update_only})
   { ##
     # Creating new caller in Parties.
     #
     if($id && $pdb->valid)
      { my $sid=$pdb->get('session');
        if($sid)
         { my $session=Symphero::MultiValueDB->new(dbh => $self->dbh, table => 'KPhoneSessions', id => $sid);
           $session->put(status => 'closed');
           $pdb->delete('session');
         }
        my $pid=$pdb->get('party');
        if($pid)
         { my $party=Symphero::MultiValueDB->new(dbh => $self->dbh, table => 'KPhoneParties', id => $pid);
           $party->put(status => 'ready');
           $party->delete('party');
           $pdb->delete('party');
         }
      }
     else
      { $id=$pdb->create;
      }
     $pdb->put(extid => $args->{extid} || '');
     $pdb->put(email => $args->{email} || '');
     $pdb->put(name => $args->{name} || '');
     $pdb->put(skill => $args->{skill}) if $args->{skill};
     $pdb->put(atime => time);
     $pdb->put(status => 'ready');
     $pdb->put(role => 'caller');
   }
  else
   { if($args->{error})
      { $self->object->display(path => $args->{error});
        return;
      }
     throw Symphero::Errors::Page "Caller cookie expired!";
   }

  ##
  # Setting the cookie and returning
  #
  my $config=$self->siteconfig;
  $config->session_specific(qw(kp_caller kp_caller_id));
  $config->put(kp_caller => $pdb);
  $config->put(kp_caller_id => $id);
  $config->add_cookie(-name    => $caller_cookie_name
                     ,-value   => $id
                     ,-path    => '/'
                     ,-expires => '+10m');
  $id;
}

##
# Logging in new agent. It is up to something external to check
# permissions, we only make the agent available here.
#
# Arguments:
#  extid => agent's external id (administrator id for example)
#  email => agent's email
#  name => agent's name or nick name
#  skills => agent's skills (comma or space separated, or array reference)
# 
# Sets agent cookie and makes an entry in KPhoneParties. Return agent ID
# and puts it into site configuration also as an 'kp_agent_id'.
#
sub agent_log_in ($;%)
{ my $self=shift;
  my $args=get_args(\@_);

  ##
  # Are we already available?
  #
  my $pdb=$self->get_party_db;
  my $id=$self->cgi->cookie($agent_cookie_name);
  $pdb->setid($id) if defined $id;
  if($id && $pdb->valid)
   { $pdb->update(atime => time);
     $pdb->put(status => 'ready') if $pdb->get('status') eq 'down';
   }
  else
   { ##
     # Creating new agent in Parties.
     #
     $id=$pdb->create;
     $pdb->put(extid => $args->{extid} || '');
     $pdb->put(email => $args->{email} || '');
     $pdb->put(name => $args->{name} || '');
     $pdb->put(atime => time);
     $pdb->put(status => 'busy');
     $pdb->put(role => 'agent');
     my @skills;
     if($args->{skills} && ref($args->{skills}) eq 'ARRAY')
      { @skills=@{$args->{skills}};
      }
     else
      { @skills=split(/[,\s]+/,$args->{skills} || '');
      }
     foreach my $skill (@skills)
      { $pdb->putsub('skill', $skill => time);
      }
   }

  ##
  # Setting the cookie and returning
  #
  my $config=$self->siteconfig;
  $config->session_specific(qw(kp_agent kp_agent_id));
  $config->put(kp_agent => $pdb);
  $config->put(kp_agent_id => $id);
  $config->add_cookie(-name    => $agent_cookie_name
                     ,-value   => $id
                     ,-path    => '/'
                     ,-expires => '+10m');
  $id;
}

##
# Setting agent status. Only allows to change busy to ready and
# back. Use drop_call to drop out of 'talking' status.
#
sub set_agent_status ($;%)
{ my $self=shift;
  my $args=get_args(\@_);
  my $ns=lc($args->{value} || $args->{status});
  return unless $ns && ($ns eq 'busy' || $ns eq 'ready');
  my $agent=$self->siteconfig->get('kp_agent');
  throw Symphero::Errors::Page ref($self)."::set_agent_id - agent must be logged in" unless $agent;
  $agent->put(status => $ns);
}

##
# Looks up call information and returns array of two parties and
# session.
#
sub get_call_info ($;%)
{ my $self=shift;
  my $config=$self->siteconfig;
  my $party1=$config->get('kp_caller') || $config->get('kp_agent');
  return (undef,undef,undef) unless $party1;
  my $party2id=$party1->get('party');
  return ($party1,undef,undef) unless $party2id;
  my $party2=$self->get_party_db;
  $party2->setid($party2id);
  return ($party1,undef,undef) unless $party2->valid;
  my $sessionid=$party1->get('session');
  return ($party1,$party2,undef) unless $sessionid;
  my $session=$self->get_session_db;
  $session->setid($sessionid);
  return ($party1,$party2,undef) unless $session->valid;
  ($party1,$party2,$session);
}

##
# Shows party information
#
sub show_party_info ($;%)
{ my $self=shift;
  my $args=get_args(\@_);
  my ($me,$party,$session)=$self->get_call_info;
  my $p=$args->{who} && $args->{who} eq 'me' ? $me : $party;
  if(!$p)
   { $self->object->display(path => $args->{error}) if $args->{error};
     return;
   }
  my $path=$args->{'success.path'} || $args->{success} || $args->{path};
  my $template=$args->{'success.template'} || $args->{template};
  if($path || $template)
   { $self->object->display(path => $path,
                            template => $template,
                            ID => $p->id,
                            STATUS => $p->get('status'),
			    EXTID => $p->get('extid') || '',
                            EMAIL => $p->get('email') || '',
                            NAME => $p->get('name') || ''
                           );
   }
}

##
# Taking call that is in 'ringing' state. Should be called only by an
# agent!
#
sub take_call ($;%)
{ my $self=shift;
  my $args=get_args(\@_);
  my ($me,$party,$session)=$self->get_call_info;
  if(!$me || !$party || !$session)
   { $self->object->display(path => $args->{error}) if $args->{error};
     return;
   }
  if($me->get('status') ne 'ringing' || $party->get('status') ne 'ringing')
   { $self->object->display(path => $args->{error}) if $args->{error};
     return;
   }
  $me->put(status => 'talking');
  $party->put(status => 'talking');
  $session->put(status => 'talking');
  $self->object->display(path => $args->{success}) if $args->{success};
}

##
# Closing party. Removes entirely if no sessions attached.
#
sub close_party ($$)
{ my $self=shift;
  my $id=shift;
  return unless $id;
  my $party=Symphero::MultiValueDB->new(dbh => $self->dbh, table => 'KPhoneParties', id => $id);
  return unless $party->valid;
  $party->put(status => 'down');
  my $role=$party->get('role');
  return unless $role;
  my $sessions=Symphero::MultiValueDB->new(dbh => $self->dbh, table => 'KPhoneSessions');
  $party->delete_all unless $sessions->listids($role => $party->id);
}

##
# Logs agent or caller out
#
sub log_out ($;%)
{ my $self=shift;
  my $config=$self->siteconfig;
  my $cname;
  my $sname;
  my $id=$config->get('kp_caller_id');
  if($id)
   { $cname=$caller_cookie_name;
     $config->delete('kp_caller_id');
     $config->delete('kp_caller');
     $sname='caller';
   }
  else
   { $id=$config->get('kp_agent_id');
     $config->delete('kp_agent_id');
     $config->delete('kp_agent');
     $cname=$agent_cookie_name;
     $sname='agent';
   }
  return unless $id;
  $self->close_party($id);

  ##
  # Removing cookie
  #
  $config->add_cookie(-name    => $cname
                     ,-value   => ''
                     ,-path    => '/'
                     ,-expires => '-10m');
}

##
# That's it
#
1;
