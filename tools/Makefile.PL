use ExtUtils::MakeMaker;

WriteMakefile( NAME => 'Symphero::Web::Tools'
             , PM => { 'create-admin.pl' => '$(INST_BIN)/create-admin.pl'
                     , 'crypto-db.pl' => '$(INST_BIN)/crypto-db.pl'
                     }
             );
