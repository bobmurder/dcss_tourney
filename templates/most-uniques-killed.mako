<%
   import loaddb, query, html
   c = attributes['cursor']

   text = html.table_text( [ 'Player', 'Uniques Slain', 'Time' ],
                           query.get_top_unique_killers(c) )
%>

${text}
