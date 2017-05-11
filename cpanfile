requires 'indirect';
requires 'Moo';
requires 'Moose';
requires 'Type::Tiny';
requires 'Time::HiRes';
requires 'Date::Utility';
requires 'Format::Util::Numbers';
requires 'Time::Duration::Concise';
requires 'YAML';
requires 'DateTime::TimeZone';
requires 'Number::Closest::XS';
requires 'List::MoreUtils';

on develop => sub {
    requires 'Devel::Cover::Report::Kritika', '>= 0.05';
};
