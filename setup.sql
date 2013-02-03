--Watchlist stores sessions that at least one user is interested in

create table Watchlist (
    SessionCode char(10) PRIMARY KEY,
    Active bit default 1,
    LastChecked datetime default CURRENT_TIMESTAMP,
    TicketsAvailable bit default 0
);

--CurrentTickets stores a row for each category of ticket available for each session
    
create table CurrentTickets (
    SessionCode char(10),
    PriceCategory char(2),
    Price money,
    Foreign key(SessionCode) references Watchlist(SessionCode)
);

--Subscriptions stores all the sessions a particular user is interested in and a strike price.

create table Subscriptions (
    SubscriptionID integer primary key autoincrement,
    SessionCode char(10),
    StrikePrice money,
    TwitterName char(50),
    Active bit default 1,
    CreationDate datetime default CURRENT_TIMESTAMP
);

--Config stores configuration data (duh)
create table Config (
    ConfigID integer primary key autoincrement,
    name varchar(100),
    value varchar(100)
);

--Events stores a Name to EventID mapping for each event code. E.g. AT005 to 0000455AC997094C. 
--This is what the London2012 ticket site uses to search ticket data for a specific event.
create table Events (
    Name varchar(20),
    EventID varchar(50)
);




