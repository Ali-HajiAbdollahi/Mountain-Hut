// Framework-independent ES module. If Vite is used, set VITE_API_BASE_URL.
const BASE=(import.meta.env?.VITE_API_BASE_URL || 'http://localhost:3001/api').replace(/\/$/,'');

async function request(path,{method='GET',body}={}) {
  const response=await fetch(`${BASE}${path}`,{
    method,credentials:'include',
    headers:body === undefined ? undefined : {'Content-Type':'application/json'},
    body:body === undefined ? undefined : JSON.stringify(body),
  });
  if (response.status === 204) return undefined;
  const data=await response.json();
  if (!response.ok) {
    const error=new Error(data.error?.message || `HTTP ${response.status}`);
    error.status=response.status; error.code=data.error?.code;
    throw error;
  }
  return data;
}
export const api={
  login:(email,password)=>request('/sessions',{method:'POST',body:{email,password}}),
  register:profile=>request('/users',{method:'POST',body:profile}),
  currentUser:()=>request('/sessions/current'),
  logout:()=>request('/sessions/current',{method:'DELETE'}),
  listSlots:date=>request(`/timeslots?date=${encodeURIComponent(date)}`),
  getSlot:id=>request(`/timeslots/${id}`),
  createSlot:body=>request('/timeslots',{method:'POST',body}),
  defineTables:(id,body)=>request(`/timeslots/${id}/tables`,{method:'PUT',body}),
  book:body=>request('/bookings',{method:'POST',body}),
  myBookings:()=>request('/bookings'),
  booking:id=>request(`/bookings/${id}`),
  resendConfirmation:id=>request(`/bookings/${id}/confirmation`,{method:'POST',body:{}}),
};