##
# Mailer object. Executes given template and send results via e-mail.
#
package Symphero::Objects::Mailer;
use strict;
use Mail::Sender 0.7;
use Symphero::Utils;
use Symphero::Objects;

##
# Inheritance
#
use vars qw(@ISA);
@ISA=Symphero::Objects->load(objname => 'Page');

##
# Displays nothing, just sends message.
#
# Arguments are:
#  to          => e-mail address of the recepient; default is taken from
#                 userdata->email if defined.
#  cc          => optional e-mail address of the seconday recepient
#  from        => optional 'from' e-mail address, default is taken from
#                 'default_from_address' site configuration parameter.
#  subject     => message subject;
#  server      => is not recommended, put server name into site configuration
#                 'smtp_server' parameter instead. Localhost is default.
#  path[.text] => text-only template path (required);
#  path.html   => html template path;
#  ARG         => VALUE - passed to Page when executing templates;
#
# If 'to', 'from' or 'subject' are not specified then get_to, get_from
# or get_subject methods are called first. Derived class may choice to
# override them. 'To' may be comma-separated addresses list.
#
# 
#
sub display ($;%)
{ my $self=shift;
  my $args=get_args(\@_);
  my $to=$args->{to};
  if(!$to)
   { my $ud=$self->{siteconfig}->get('userdata');
     $to=$ud ? $ud->get('email') : $self->get_to;
   }
  $to || throw Symphero::Errors::Page ref($self)."::display - no 'to' given";
  my $from=$args->{from} || $self->{siteconfig}->get('default_from_address');
  $from || throw Symphero::Errors::Page ref($self)."::display - no 'from' given";
  my $subject=$args->{subject} || $self->{siteconfig}->get('sitedesc') || 'No subject';
  my $server=$args->{server} || $self->{siteconfig}->get('smtp_server') || '127.0.0.1';

  ##
  # Parsing text template
  #
  my $textpath=$args->{'path.text'} || $args->{path};
  $textpath || throw Symphero::Errors::Page ref($self)."::display - no text path given";
  my $obj=$self->object;
  my %objargs=%{$args};
  delete $objargs{template};
  $objargs{path}=$textpath;
  my $text=$obj->expand(\%objargs);
  $text || throw Symphero::Errors::Page ref($self)."::display - template $textpath produced no text";

  ##
  # Parsing HTML template
  #
  my $html;
  if($args->{'path.html'})
   { %objargs=%{$args};
     delete $objargs{template};
     $objargs{path}=$args->{'path.html'};
     $html=$obj->expand(\%objargs);
   }

  ##
  # Preparing mailer
  #
  my $mailer=Mail::Sender->new({ smtp => $server });
  if($html)
   { $mailer->OpenMultipart({ from => $from
                            , to => $to
                            , cc => $args->{cc}
                            , subject => $subject
                            , multipart => 'Alternative'
                            });
     $mailer->Body;
     $mailer->Send($text);
     $mailer->Part({ ctype => 'text/html'});
     $mailer->Send($html);
     $mailer->Close;
   }
  else
   { $mailer->Open({ from => $from
                   , to => $to
                   , cc => $args->{cc}
                   , subject => $subject
                   });
     $mailer->Send($text);
     $mailer->Close;
   }
}

##
# That's it
#
1;
