use covid_19;

										/*STEP 1 - Transformation data to suitable types and formats*/

-- Transaction control commands  and  Command for tracing results 
commit;
select * from deaths;
rollback;

-- Changing commas to dots for changing data types in the future --
	UPDATE info 
    SET excess_mortality = replace(excess_mortality, ',', '.');

-- Changing 'None' to 0 --
	UPDATE info 
    SET new_vaccinations_smoothed_per_million = replace(new_vaccinations_smoothed_per_million, 'None', '0');
    
-- Changing Empty cells to 0 --
	update info
    set excess_mortality = '0'
    where excess_mortality = '';


-- Changing Data Type --
	alter table vaccination modify date date; 

														/*STEP 2 - Coding QUERIES*/ 

-- QUERY 1
-- This is a basic query which can be useful for visualising the overall picture of the pandemic in Finland 
select 
	d.location,
	d.date,
    d.population,
	d.total_cases,
	d.new_cases,
	d.total_deaths, 
    v.total_vaccinations
from 
	deaths d
join
	vaccination v on d.location = v.location and v.date = d.date
where v.continent not like '0' and v.location like '%Finland%'
order by 1,2;


-- QUERY 2
-- It shows the first death in Finland 
select 
	date,
    new_deaths 
from deaths
where location like '%Finland%' 
	and new_deaths = 1 
order by date asc
limit 1;


-- QUERY 3
-- Here we can see Deaths/Cases ratio and its maximum
select 
	location,
	date,
	total_deaths,
	total_cases,
	Round(cast(total_deaths as float)/cast(total_cases as float) * 100, 2) as 'death_ratio(%)',
    Max(round(cast(total_deaths as float)/cast(total_cases as float) * 100, 2)) over (Partition by location) as 'max_ratio(%)'
from deaths
where location like '%Finland%'
order by 2;


-- QUERY 4
-- lets imaging we are a goverment and we need to decide to what countries flights should be stopped
-- Technical task: define countries with the case_rate exceeded 15% for terminating flights to these countries
select 
	location,
	population, 
	max(total_cases) as highest_Cases_Count,
	round(Max((total_cases/population))*100, 2) as max_case_percentage,
    case 
		when round(Max((total_cases/population))*100, 2) > 15 then 'stop flying' 
        else 'Keep flying'
	end as Decision 
from deaths
	where continent not like '0'
Group by location, population
order by 4 desc, 1
limit 10;


-- QUERY 5 
-- GLOBAL NUMBERS
select 
	date,
    extract(year from date) as year,
	sum(total_cases) as total_case,
    sum(total_deaths) as total_death,
	round(sum(total_deaths) / sum(total_cases) *100, 2) as 'death_rate(%)',
    max(round(sum(total_deaths) / sum(total_cases) *100, 2)) 
		over (partition by extract(year from date)) as 'highest_rate_by_years(%)'
from deaths
where continent not like '%0%'
group by date
order by 1, 2;



-- QUERY 6 
-- COMMON TABLE EXPRESION 
-- It shows a pace of vaccination
With CTE (continent, location, date, population, new_vaccinated, rolling_vaccinated)
as
(
Select 
	d.continent,
	d.location,
    d.date,
    d.population,
    v.new_vaccinations,
    sum(v.new_vaccinations) over (partition by d.location order by d.location, d.date) as rolling_vaccinated 
from 
	vaccination v
join  
	deaths d on v.location = d.location and v.date = d.date
where d.continent not like '0'
Order by 2,3
)

select *, round((rolling_vaccinated / population) * 100, 2) as rolling_vaccinated_over_population
from CTE;



-- QUERY 7
-- Temporary table 
-- It shows the same, but using a temporary table
Create temporary table Percent_Population_Vaccinated
(
continent nvarchar(255),
location nvarchar(255),
date date,
population numeric,
new_vaccinated numeric,
Rolling_People_vaccinated numeric
);

Insert into Percent_Population_Vaccinated
	Select 
		d.continent,
		d.location,
		d.date,
		d.population,
		v.new_vaccinations,
		sum(v.new_vaccinations) over (partition by d.location order by d.location, d.date) as rolling_vaccinated 
	from 
		vaccination v
	join  
		deaths d on v.location = d.location and v.date = d.date
	where d.continent not like '0'
	Order by 2,3;

select *, (Rolling_People_vaccinated / population)*100 
from Percent_Population_Vaccinated;


-- QUERY 8
-- Views 
-- It shows the same, but using a view
drop view if exists Percentage_Poplation_Vaccinated;
Create view Percentage_Poplation_Vaccinated as 
	Select 
		d.continent,
		d.location,
		d.date,
		d.population,
		v.new_vaccinations,
		sum(v.new_vaccinations) over (partition by d.location order by d.location, d.date) as rolling_vaccinated 
	from 
		vaccination v
	join  
		deaths d on v.location = d.location and v.date = d.date
	where d.continent not like '0'
	Order by 2,3;

	select *, (rolling_vaccinated / population)*100 
	from Percentage_Poplation_Vaccinated;
    
    

-- QUERY 9
-- Stord Procedures 
-- It shows a number of cases for certain dates 
drop procedure if exists cases_per_dates; 
	DELIMITER $$
Create procedure cases_per_dates (in p_starting_date date, in p_ending_date date)
begin 
	select 
		d.location,
		d.date,
        d.new_cases,
        SUM(d.new_cases) over (Partition by d.location) as Total_new_cases_for_these_dates,
        v.new_vaccinations,
         SUM(v.new_vaccinations) over (Partition by d.location) as Total_new_vaccinations_for_these_dates
	from 	
		deaths d
			join
		vaccination v on d.date = v.date and d.location = v.location
    where d.date >= p_starting_date and d.date <= p_ending_date and d.location like '%Finland%'
    order by d.location, d.date;

end$$
	DELIMITER ;




