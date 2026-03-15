--Enunciado 1: Explora el fichero flights y analiza

	--Check the table and visualise which columns are included
	select *
	from flights
	where unique_identifier = 'EI-8337-20230630-DUB-LHR'
	limit 10;
	/*
	Use columns "flight_row_id" and	"unique_identifier" because the	first one seems
	to have a sequential order numbering the rows	and the second one corresponds
	to a unique identifier probably to the flight.
	*/

	--1. Cuántos registros hay en total: 1209 registros/filas
	select
		count(*) as total_elements,
		count(flight_row_id) as total_flight_rows
	from flights;
	
	--2. Cuántos vuelos distintos hay: 266 vuelos
	select
		count(distinct unique_identifier) as total_fligths_id
	from flights;
	
	--3. Cuántos vuelos tienen más de un registro: 250 vuelos
	/*
	Use a CTE to construct the list of flights with the	amount of records for each
	and then, over this query, count the amount of flights with more than 1 record.
	*/
	with count_flight_reports as (
		select
			unique_identifier as flight_id,
			count(flight_row_id) as reports_count
		from flights
		group by flight_id
		order by reports_count desc
	)
	select
		count(flight_id) as total_flights
	from count_flight_reports
	where reports_count > 1;

--Enunciado 2: Por qué hay registros duplicados para un mismo vuelo.
--Para ello, selecciona varios vuelos y analiza la evolución temporal de cada vuelo.

	--1. Qué información cambia de un registro a otro:
	
	/*De acuerdo el análisis paso a paso que se presenta a continuación, las
	diferencias en todos los registros de un mismo vuelo se concentran en las
	columnas:
	
		local_actual_departure y local_actual_arrival: Puede ser vacío o tener
		información, existen casos límite que deberán ser evaluados más adelante
		porque tienen fechas diferentes en registros con datos.
		(ej: QR-3758-20231122-SVQ-BCN y BA-4209-20240715-MAD-GIG)
	
		delay_mins: Puede ser vacío o tener información y es reportado en función
		de la diferencia entre local_actual_arrival y local_arrival.
	
		arrival_status: Pueden cambiar en todos los registros y puede ser NULL, EY,
		NS, CX, DY y OT.
	
		updated_at: No todos los vuelos tienen ésta información pero los que sí
		cambian en cada registro.
	*/
	
	/*
	Evaluate how many different elements exist in each column for all the flights
	in order to identify the ones that change.
	*/
	with column_elements_counter as (
		select
			unique_identifier,
			count(*) as records_amount,
			count(distinct local_departure) as local_departure_amount,
			count(distinct local_actual_departure) as local_actual_departure_amount,
			count(distinct local_arrival) as local_arrival_amount,
			count(distinct local_actual_arrival) as local_actual_arrival_amount,
			count(distinct departure_airport) as departure_airport_amount,
			count(distinct arrival_airport) as arrival_airport_amount,
			count(distinct airline_code) as airline_code_amount,
			count(distinct delay_mins) as delay_mins_amount,
			count(distinct arrival_status) as arrival_status_amount,
			count(distinct created_at) as created_at_amount,
			count(distinct updated_at) as updated_at_amount
		from flights
		group by unique_identifier
		order by records_amount desc, unique_identifier asc
	)
	select
		max(local_departure_amount) as max_local_departure_amount,
		max(local_actual_departure_amount) as max_local_actual_departure_amount,
		max(local_arrival_amount) as max_local_arrival_amount,
		max(local_actual_arrival_amount) as max_local_actual_arrival_amount,
		max(departure_airport_amount) as max_departure_airport_amount,
		max(arrival_airport_amount) as max_arrival_airport_amount,
		max(airline_code_amount) as max_airline_code_amount,
		max(delay_mins_amount) as max_delay_mins_amount,
		max(arrival_status_amount) as max_arrival_status_amount,
		max(created_at_amount) as max_created_at_amount,
		max(updated_at_amount) as max_updated_at_amount
	from column_elements_counter;
	
	/*
	The local_departure and created_at columns either have one element or don't
	have; local_arrival, departure_airport, arrival_airport and airline_code in
	every flight is just one.
	For the previous reasons this columns won't be use in the next analysis
	considering that in every record stay the same.
	
	Use top 5 flights with more records to identify what changes:
	'AV-47-20211101-MAD-BOG'
	'EI-8337-20230630-DUB-LHR'
	'KL-1704-20240111-MAD-AMS'
	'KL-988-20220801-LCY-AMS'
	'HO-1306-20221014-HKG-NKG'
	
	Record with multiple updated_at:
	'AA-102-20241001-JFK-MAD'
	'AA-148-20240809-JFK-MAD'
	'AR-181-20240901-EZE-MAD'
	*/
	select
		flight_row_id,
		unique_identifier,
		local_departure,
		local_actual_departure,
		local_arrival,
		local_actual_arrival,
		delay_mins,
		arrival_status,
		updated_at
	from flights
	where unique_identifier = 'HO-1306-20221014-HKG-NKG'
	order by
		updated_at desc,
		local_actual_departure asc,
		local_actual_arrival asc;
	/*
	Is found during the previous exploration that there are records without
	information of updated_at probably because it was manually registered.
	
	The arrival status could be a good indicator of progression.
	*/
	select
		distinct arrival_status
	from flights;

--Enunciado 3: Evalúa la calidad del dato. La calidad del dato nos indica si
--la información es consistente, completa, coherente y representa una realidad
--verosímil. Para ello debemos establecer unos criterios:

	--1. La información de created_at debe ser única para cada vuelo aunque
	--tenga más de un registro: OK
	with column_elements_counter as (
		select
			unique_identifier,
			count(distinct created_at) as created_at_amount
		from flights
		group by unique_identifier
		order by unique_identifier asc
	)
	select
		max(created_at_amount) as max_created_at_amount
	from column_elements_counter;
	
	--2. La información de updated_at deber ser igual o más que la información
	--de created_at, lo que nos indica coherencia y consistencia: OK
	with flights_info as (
		select
			unique_identifier,
			created_at,
			updated_at,
			extract(epoch from updated_at - created_at) as diff_seconds
		from flights
		order by diff_seconds asc
	)
	select *
	from flights_info
	where diff_seconds < 0;

--Enunciado 4: El último estado de cada vuelo. Cada vuelo puede aparecer varias
--veces en el dataset, para avanzar con nuestro análisis necesitamos quedarnos
--solo con el último registro de cada vuelo.

	--How many flights don't have updated_at? 43
	select
		count(distinct unique_identifier) as total
	from flights
	where updated_at is NULL;
	/*
	In order to select the last record for each flight according to previous
	exploration the records for each flight must be organise in a window function
	first by updated_at in a descending order and then in ascending order by
	local_actual_departure and local_actual_arrival (it uses ascending order to
	avoid the firsts records where this columns where NULL).
	
	The record to select will be the first one in the organised window.
	*/
	
	--Create table for the last record of each flight:
	create table if not exists flights_last_record (
	  flight_row_id BIGSERIAL primary key,
	  unique_identifier text,
	  local_departure timestamp,
	  local_actual_departure timestamp,
	  local_arrival timestamp,
	  local_actual_arrival timestamp,
	  gmt_departure timestamp,
	  gmt_actual_departure timestamp,
	  gmt_arrival timestamp,
	  gmt_actual_arrival timestamp,
	  departure_airport char(3),
	  arrival_airport char(3),
	  airline_code char(2),
	  delay_mins integer,
	  arrival_status text,
	  created_at timestamp,
	  updated_at timestamp
	);
	
	INSERT INTO flights_last_record (
		flight_row_id, unique_identifier, local_departure, local_actual_departure,
		local_arrival, local_actual_arrival, gmt_departure, gmt_actual_departure,
		gmt_arrival, gmt_actual_arrival, departure_airport, arrival_airport,
		airline_code, delay_mins, arrival_status, created_at, updated_at
	)
	with classification as (
		select
			*,
			row_number() over(
				partition by unique_identifier
				order by
					updated_at desc,
					local_actual_departure asc,
					local_actual_arrival asc
			) as rn
		from flights
	)
	select
		flight_row_id, unique_identifier, local_departure, local_actual_departure,
		local_arrival, local_actual_arrival, gmt_departure, gmt_actual_departure,
		gmt_arrival, gmt_actual_arrival, departure_airport, arrival_airport,
		airline_code, delay_mins, arrival_status, created_at, updated_at
	from classification
	where rn = 1;

--Enunciado 5: Considerando que los campos local_departure y local_actual_departure
--son necesarios para el análisis, valida y reconstruye estos valores siguiendo
--estas reglas:
--1. Si local_departure es nulo, utiliza created_at.
--2. Si local_actual_departure es nulo, utiliza local_departure. Si este también
--es nulo, utiliza created_at.

	--1. Crea dos nuevos campos: effective_local_departure y
	--effective_local_actual_departure
	alter table flights_last_record
	add column effective_local_departure timestamp,
	add column effective_local_actual_departure timestamp;
	
	update flights_last_record
	set
		effective_local_departure =
			case
				when local_departure is NULL then created_at
				else local_departure
			end,
		effective_local_actual_departure =
			case
				when local_actual_departure is NULL and local_departure is NULL then created_at
				when local_actual_departure is NULL then local_departure
				else local_actual_departure
			end;

	--Extra: Realiza las validaciones para los campos local_arrival y
	--local_actual_arrival.
	
	select
		unique_identifier,
		local_arrival
	from flights_last_record
	where local_arrival is not NULL;
	/*
	Every flight has local_arrival so we will create just the
	effective_local_actual_arrival column either with its value
	or if it's NULL with the local_arrival as preliminary.
	*/
	
	alter table flights_last_record
	add column effective_local_actual_arrival timestamp;
	
	update flights_last_record
	set
		effective_local_actual_arrival =
			case
				when local_actual_arrival is NULL then local_arrival
				else local_actual_arrival
			end;

--Enunciado 6: Análisis del estado del vuelo. Haciendo uso del resultado del
--enunciado 4, analiza los estados de los vuelos.

	--1. ¿Qué estados de vuelo existen? EY, NS, CX, DY, OT o NULL
	select
		distinct arrival_status
	from flights_last_record
	order by arrival_status asc;
	
	--2. ¿Cuántos vuelos hay por cada estado? DY 153, OT 83, EY 18, CX 5
	--NS 3 y sin estado 4
	select
		distinct arrival_status,
		count(unique_identifier) as number_of_flights
	from flights_last_record
	group by arrival_status
	order by number_of_flights desc;
	
	--¿Podrías decir qué significa las siglas de cada estado?
	/*
	DY = Delayed, local_departure is before local_actual_departure which
	generates possible delays.
	OT = On Time, local_departure and local_actual_departure the same,
	minimum delays and mostly in favor.
	EY = Early, with information of actual departure and arrival; also,
	early arrival from original plan.
	CX = Cancelled, without information of actual departure and arrival
	with updated_at different than created_at.
	NS = Unknown, without actual_arrival information, it seems like the flight
	started, the records don't have information of created_at or updated_at
	*/
	select *
	from flights_last_record
	where arrival_status = 'OT';

--Enunciado 7: País de salida de cada vuelo. Tienes disponible un csv. con
--información de aeropuertos airports.csv. Haciendo uso del resultado del
--enunciado 4, analiza los aeropuertos de salida.

	--1. ¿De qué país despegan los vuelos?
	/*
	France, Germany, Italy, Netherlands, Spain, United Kingdom and United
	States. There are 43 flights from which we have the departure airport 
	code but no information in the airports table.
	*/
	--2. ¿Cuántos vuelos despegan por país?
	/*
	Spain 131, France 27, United States 26, Netherlands 19, United Kingdom 18
	Germany 1 and Italy 1. There are 43 flights from which we have the
	departure airport code but no information in the airports table.
	*/
	with departure_info as (
		select
			air.country,
			fli.departure_airport,
			count(distinct fli.unique_identifier) as number_of_flights
		from flights_last_record as fli
		left join airports as air
		on fli.departure_airport = air.airport_code
		group by air.country, fli.departure_airport
	)
	select
		country,
		sum(number_of_flights)
	from departure_info
	group by country;
	
--Enunciado 8: Delay medio y estado de vuelo por país de salida. Haciendo uso
--del resultado del enunciado 4, analiza el estado y el delay/retraso medio con
--el objetivo de identificar si existen países que pueden presentar problemas
--operativos en los aeropuertos de salida.

	--1. ¿Cuál es el delay medio por país?
	/*
	France			  8.81
	Germany			 10.00
	Italy			 -5.00
	Netherlands		  0.16
	Spain			  6.43
	United Kingdom	  2.67
	United States	 11.62
	*/
	with departure_info as (
		select
			air.country,
			fli.arrival_status,
			fli.delay_mins,
			count(distinct fli.unique_identifier) as number_of_flights
		from flights_last_record as fli
		left join airports as air
		on fli.departure_airport = air.airport_code
		group by air.country, fli.arrival_status, fli.delay_mins
	)
	select
		country,
		sum(delay_mins * number_of_flights) / sum(number_of_flights) as average_delay
	from departure_info
	group by country;

	--2. ¿Cuál es la distribución de estados de vuelos por país?
	/*
	France			DY		 85,19 %
	France			EY		  3,70 %
	France			OT		 11,11 %
	Germany			DY		100,00 %
	Italy			EY		100,00 %
	Netherlands		DY		 52,63 %
	Netherlands		EY		  5,26 %
	Netherlands		OT		 42,11 %
	Spain			CX		  0,76 %
	Spain			DY		 52,67 %
	Spain			EY		  3,82 %
	Spain			NS		  0,76 %
	Spain			OT		 39,69 %
	Spain			NULL	  2,29 %
	United Kingdom	DY		 61,11 %
	United Kingdom	OT		 38,89 %
	United States	CX		  3,85 %
	United States	DY		 65,38 %
	United States	EY		  3,85 %
	United States	OT		 26,92 %
	*/
	with country_info as (
		select
			air.country,
			fli.arrival_status,
			fli.delay_mins,
			count(distinct fli.unique_identifier) as number_of_flights
		from flights_last_record as fli
		left join airports as air
		on fli.departure_airport = air.airport_code
		group by air.country, fli.arrival_status, fli.delay_mins
	), status_info as (
		select
			country,
			arrival_status,
			sum(number_of_flights) as number_of_flights
		from country_info
		group by country, arrival_status
	), flights_distribution as (
		select
			country,
			arrival_status,
			number_of_flights / sum(number_of_flights) over(partition by country)
			as flights_distribution
		from country_info
	)
	select
		country,
		sum(flights_distribution) filter (where arrival_status = 'EY') as early,
		sum(flights_distribution) filter (where arrival_status = 'NS') as unknown,
		sum(flights_distribution) filter (where arrival_status = 'CX') as cancelled,
		sum(flights_distribution) filter (where arrival_status = 'DY') as delayed,
		sum(flights_distribution) filter (where arrival_status = 'OT') as on_time
	from flights_distribution
	group by country;

--Enunciado 9: El estado de vuelo por país y por época del año. Dado que no en todas
--las épocas del año las condiciones climatólogicas son iguales, analiza si la
--estaciones del año impactan en el delay medio por país. Considera la siguiente
--clasificación de meses del año por época:
--Invierno: diciembre, enero, febrero
--Primavera: marzo, abril, mayo
--Verano: junio, julio, agosto
--Otoño: septiembre, octubre, noviembre

	--Estado de vuelo por país y por época del año:
	/*
	Se revisa principalmente el estado de los vuelos retrasados que son los que impactan
	principalmente en el promedio de retraso.
	
	Country		 Average Delay		Seasons impact?
	
	France			  8.81			Se observa una reducción en los tiempos de retraso
									de los vuelos en primavera, es importante identificar
									las causas para ver si se puede tomar acción y
									beneficiar otras temporadas.
									A pesar de que hay un incremento en vuelos en la
									temporada de invierno, no se observan incrementos
									inusuales en los tiempos de retraso.
									
	Netherlands		  0.16			Se observa un impacto en el tiempo de retraso en 
									invierno de 2.8 veces el tiempo promedio de las
									otras temporadas a pesar de que es una de las
									temporadas con menor cantidad de vuelos.
									
	Spain			  6.43			Invierno, a pesar de ser la temporada con mayor
									cantidad de vuelos, es la que menos retrasos tiene
									y en la que más tiempo se ahorra cuando llegan
									temprano. Se observan incrementos en el tiempo de
									retraso en otoño y primavera que deben ser revisados.
									
	United Kingdom	  2.67			Se observa que en invierno se cuenta con el menor
									tiempo de retraso en vuelos y sería importante
									conocer las causas para reducir los tiempos de otoño
									y primavera que son los que impactan mayoritariamente
									el tiempo promedio de retraso del país.
									
	United States	 11.62			Se observan tiempos de retraso superiores a la media
									en otoño (temporada con mayor cantidad de vuelos) y un
									comportamiento inusual en verano, cuyos tiempos de retraso
									se reducen en un 69% frente a la media, es importante
									identificar las causas de ésta reducción para poder
									aplicar ajustes en las otras temporadas.
	*/
	with month_info as (
		select
			extract(month from effective_local_departure) as month,
			unique_identifier,
			departure_airport,
			case 
				when arrival_status = 'EY' then 'Early'
				when arrival_status = 'NS' then 'Unknown'
				when arrival_status = 'CX' then 'Cancelled'
				when arrival_status = 'DY' then 'Delayed'
				when arrival_status = 'OT' then 'On time'
			end as arrival_status,
			delay_mins
		from flights_last_record
	), season_info as (
		select
			unique_identifier,
			case 
				when month in (12, 1, 2) then 'Winter'
				when month in (3, 4, 5) then 'Spring'
				when month in (6, 7, 8) then 'Summer'
				when month in (9, 10, 11) then 'Autumn'
			end as season,
			departure_airport,
			arrival_status,
			delay_mins
		from month_info
	), country_info as (
		select
			air.country,
			sea.season,
			sea.arrival_status,
			sum(sea.delay_mins) as total_delay_mins,
			count(distinct sea.unique_identifier) as total_flights
		from season_info as sea
		left join airports as air
		on sea.departure_airport = air.airport_code
		group by air.country, sea.season, sea.arrival_status
	), average_delay as(
		select
			country,
			arrival_status,
			season,
			total_flights,
			total_delay_mins::numeric / total_flights as average_delay_per_flight,
			sum(total_flights) over (partition by country) as country_total_flights,
			sum(total_flights) over (partition by country, arrival_status) as status_total_flights,
			sum(total_flights) over (partition by country, season) as season_total_flights,
			sum(total_delay_mins) over (partition by country) as country_total_delay,
			sum(total_delay_mins) over (partition by country, arrival_status) as status_total_delay
		from country_info
		order by country, arrival_status
	)
	select
		country,
		arrival_status,
		season,
		total_flights,
		country_total_flights,
		status_total_flights,
		season_total_flights,
		average_delay_per_flight,
		country_total_delay::numeric / country_total_flights as country_average_delay_per_flight,
		status_total_delay::numeric / status_total_flights as country_status_average_delay_per_flight
	from average_delay
	order by country, arrival_status;

--Enunciado 10: Frecuencia de actualización de los vuelos.
--Volviendo al análisis de la calidad del dataset, explora con qué frecuencia
--se registran actualizaciones de cada vuelo y calcula la frecuencia media de
--actualización por aeropuerto de salida.
	
	with update_frecuency as (
		select
			departure_airport,
			unique_identifier,
			count(flight_row_id) as update_frequency--Is not possible to use
			--updated_at considering all the records don't have this info.
		from flights
		--where departure_airport in ('FCO', 'MUC')
		group by departure_airport, unique_identifier
	), average_update as (
		select
			air.airport_name,
			avg(upd.update_frequency) as average_update_frequency
		from update_frecuency as upd
		left join airports as air
		on upd.departure_airport = air.airport_code
		group by air.airport_name
	)
	select *
	from average_update
	order by airport_name;
	/*
	Adolfo Suárez Madrid–Barajas Airport	 4.1
	Amsterdam Airport Schiphol				 4.6
	Barcelona–El Prat Airport				 3.1
	Charles de Gaulle Airport				 3.6
	Heathrow Airport						 3.7
	John F. Kennedy International Airport	 3.1
	Leonardo da Vinci–Fiumicino Airport		 8.0
	Munich Airport							10.0
	*/

--Enunciado 11: Consistencia del dato. El campo unique_identifier identifica
--el vuelo y se construye con: aerolínea, número de vuelo, fecha y aeropuertos.
--Para cada vuelo (último snapshot), comprueba si la información del
--unique_identifier es consistente con las columnas del dataset.

	--1. Crea un flag is_consistent: ok
	with consistency as (
		select
			unique_identifier,
			split_part(unique_identifier, '-', 1) = airline_code and
			split_part(unique_identifier, '-', 3) = concat(
														extract(year from local_departure),
														to_char(extract(month from local_departure), 'FM00'),
														to_char(extract(day from local_departure), 'FM00')) and
			split_part(unique_identifier, '-', 4) = departure_airport and
			split_part(unique_identifier, '-', 5) = arrival_airport as is_consistent	
		from flights_last_record
	)
	select *
	from consistency;
	
	--2. Calcula cuántos vuelos no son consistentes: 15
		with consistency as (
		select
			unique_identifier,
			split_part(unique_identifier, '-', 1) = airline_code and
			split_part(unique_identifier, '-', 3) = concat(
														extract(year from local_departure),
														to_char(extract(month from local_departure), 'FM00'),
														to_char(extract(day from local_departure), 'FM00')) and
			split_part(unique_identifier, '-', 4) = departure_airport and
			split_part(unique_identifier, '-', 5) = arrival_airport as is_consistent	
		from flights_last_record
	)
	select
		count(unique_identifier) as inconsistent_flights
	from consistency
	where not is_consistent;
	
	--3. Usando la tabla airlines, muestra el nombre de la aerolínea y cuántos
	--vuelos no consistentes tiene
	with consistency as (
		select
			split_part(unique_identifier, '-', 1) as airline_code,
			unique_identifier,
			split_part(unique_identifier, '-', 1) = airline_code and
			split_part(unique_identifier, '-', 3) = concat(
														extract(year from local_departure),
														to_char(extract(month from local_departure), 'FM00'),
														to_char(extract(day from local_departure), 'FM00')) and
			split_part(unique_identifier, '-', 4) = departure_airport and
			split_part(unique_identifier, '-', 5) = arrival_airport as is_consistent	
		from flights_last_record
	)
	select
		air.name,
		count(unique_identifier) as inconsistent_flights
	from consistency as con
	left join airlines as air
	on con.airline_code = air.airline_code
	where not is_consistent
	group by air.name;
	